# Auto-import birding photos from the Canon camera (PTP / gphoto2).
#
# The Canon body (USB 04a9:32f7) enumerates as a PTP device, NOT a mountable
# disk (it shows in `lsusb` but never in `lsblk`), so frames are pulled with
# gphoto2 rather than mount + rsync. exiftool then files each frame into
# /nas/andreas/photography/<yymmdd> by its EXIF capture date, so a multi-day
# trip fans out into per-day folders.
#
# The SD card is NEVER touched — this only copies; the card is wiped by hand.
# That also makes the card the safety net: a partial or failed NAS write loses
# nothing, since the originals are still on the card until you clear it.
#
# Trigger: a NixOS udev rule starts the `camera-import` systemd *user* service
# on plug-in. That rule is system-side (it lives in terra's NixOS config, not
# here — see the block at the bottom of this file), consistent with the
# device-rule convention in CLAUDE.md. The service and the hand-runnable
# `camera-import` command are the same writeShellApplication.
{ pkgs, ... }:
let
  dest = "/nas/andreas/photography";
  nasMount = "/nas";

  camera-import = pkgs.writeShellApplication {
    name = "camera-import";
    runtimeInputs = [
      pkgs.gphoto2 # pull files off the camera over PTP
      pkgs.exiftool # read EXIF capture date + file into date folders
      pkgs.libnotify # notify-send — desktop notifications (errors)
      pkgs.quickshell # qs ipc call — drive the progress OSD in the bar
      pkgs.util-linux # mountpoint
      pkgs.coreutils # mktemp / seq / rm / stdbuf
    ];
    text = ''
      dest=${dest}
      nas_mount=${nasMount}

      # Push progress into the Quickshell OSD (CameraImport.qml). Best-effort: if
      # the bar isn't running the calls just fail and the import proceeds.
      qsipc() { qs ipc call cameraImport "$@" >/dev/null 2>&1 || true; }
      # notify-send must never abort the script (set -e): the user bus may not be
      # reachable, and a missing toast is not a failure.
      note() { notify-send -a camera-import "Camera import" "$1" || true; }
      fail() { qsipc fail "$1"; note "⚠ $1"; echo "camera-import: $1" >&2; exit 1; }

      # Guard: never write into an unmounted mountpoint, or we would silently
      # fill the local root disk under /nas instead of the NAS share.
      mountpoint -q "$nas_mount" || fail "$nas_mount is not mounted — aborting."

      # udev can fire a moment before the camera answers PTP; give it a few tries.
      for _ in $(seq 1 10); do
        gphoto2 --auto-detect 2>/dev/null | grep -qE 'usb:[0-9]' && break
        sleep 1
      done
      gphoto2 --auto-detect 2>/dev/null | grep -qE 'usb:[0-9]' \
        || fail "no camera detected over PTP."

      # Best-effort total for the progress bar: count the files the camera lists.
      # If this comes back 0 (some bodies don't list recursively), the OSD just
      # shows an indeterminate marquee instead of a percentage.
      total=$(gphoto2 --list-files 2>/dev/null | grep -cE '^#[0-9]' || true)
      qsipc start "$total"

      staging=$(mktemp -d)
      # shellcheck disable=SC2064
      trap "rm -rf '$staging'" EXIT

      # Pull everything off the card into local staging first. --skip-existing
      # keeps gphoto2 non-interactive — otherwise a duplicate basename across two
      # camera folders would prompt "overwrite?" and hang the service. The card
      # is left completely untouched. We stream gphoto2's output (line-buffered
      # via stdbuf) and tick the OSD on each saved file. pipefail propagates a
      # gphoto2 failure out of the pipe so the guard below catches it.
      if ! ( cd "$staging" && stdbuf -oL gphoto2 --get-all-files --skip-existing 2>&1 ) \
        | while IFS= read -r line; do
            case "$line" in
              'Saving file as'*) count=$((''${count:-0} + 1)); qsipc progress "$count" "$total" ;;
            esac
          done; then
        fail "gphoto2 download failed."
      fi
      # ── Filing phase ──────────────────────────────────────────────────────
      # Hand the OSD over to the second phase: exiftool now copies each frame
      # onto the NAS (the slow part — tens of GB over SMB). gphoto2 saved all
      # frames flat into staging, so a glob counts them for the initial total.
      shopt -s nullglob
      staged_files=("$staging"/*)
      shopt -u nullglob
      qsipc filing "''${#staged_files[@]}"

      # File each frame into <dest>/<yymmdd> by capture date. The -Directory
      # redirects are tried in order and the LAST one with a value wins, so
      # DateTimeOriginal (most reliable) takes precedence, falling back to
      # CreateDate, then the file mtime. exiftool refuses to overwrite an
      # existing target, so frames already on the NAS are skipped — re-plugging a
      # not-yet-wiped card is a cheap no-op on the NAS side (it does re-pull from
      # the card over PTP, so wipe the card after a good import to keep it fast).
      #
      # -progress makes exiftool print "======== <path> [N/M]" per file; we parse
      # that to drive the bar, while tee keeps the full output so the final
      # "N image files updated" count is still available below. || true: exiftool
      # exits non-zero on benign warnings (e.g. a skipped duplicate).
      exlog=$(mktemp)
      stdbuf -oL -eL exiftool -progress -r -d "$dest/%y%m%d" \
        '-Directory<FileModifyDate' \
        '-Directory<CreateDate' \
        '-Directory<DateTimeOriginal' \
        "$staging" 2>&1 | tee "$exlog" | while IFS= read -r line; do
          case "$line" in
            ========*"["*"/"*"]"*)
              prog=''${line##*[}; prog=''${prog%]*}
              qsipc progress "''${prog%/*}" "''${prog#*/}"
              ;;
          esac
        done || true
      out=$(cat "$exlog"); rm -f "$exlog"

      # exiftool reports e.g. "152 image files updated" (skipped duplicates are
      # warnings, not "updated"), so this is the count actually filed to the NAS.
      imported=$(printf '%s\n' "$out" | grep -oE '[0-9]+ image files? updated' \
        | grep -oE '^[0-9]+' | head -1)
      imported=''${imported:-0}

      # If exiftool errored out and nothing landed, surface it rather than
      # claiming success with a count of 0.
      if [ "$imported" -eq 0 ] && printf '%s\n' "$out" | grep -qi 'due to errors'; then
        fail "filing into $dest failed — see: journalctl --user -u camera-import"
      fi

      qsipc finish "$imported"
    '';
  };
in
{
  # Also available by hand for the first run / debugging: `camera-import`.
  home.packages = [ camera-import ];

  # Started on plug-in by the NixOS udev rule below (not WantedBy anything here —
  # udev's SYSTEMD_USER_WANTS pulls it in). oneshot: run, notify, exit.
  systemd.user.services.camera-import = {
    Unit = {
      Description = "Import photos from the camera (gphoto2 → NAS by EXIF date)";
      # Needs the graphical session's NAS mount + notification bus.
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${camera-import}/bin/camera-import";
    };
  };

  # ---------------------------------------------------------------------------
  # NixOS side (NOT applied by home-manager — add this to terra's system config):
  #
  #   services.udev.extraRules = ''
  #     ACTION=="remove", GOTO="cam_import_end"
  #     SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", \
  #       ATTR{idVendor}=="04a9", ATTR{idProduct}=="32f7", \
  #       TAG+="systemd", ENV{SYSTEMD_USER_WANTS}+="camera-import.service"
  #     LABEL="cam_import_end"
  #   '';
  #
  # ENV{DEVTYPE}=="usb_device" matches the camera once (not per USB interface).
  # idProduct 32f7 is this specific body/mode; broaden to just idVendor 04a9 to
  # catch any Canon body, at the cost of also matching Canon printers/scanners.
  # ---------------------------------------------------------------------------
}
