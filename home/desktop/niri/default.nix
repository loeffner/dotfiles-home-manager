# niri compositor — hand-written KDL config (no home-manager module needed).
# Split by concern: ./settings.nix (input/layout/env/autostart) and ./binds.nix
# (keybinds) are assembled into config.kdl below; ./clipboard.nix carries the
# Win+V clipboard picker. Reference:
# https://github.com/YaLTeR/niri/wiki/Configuration:-Overview
{
  config,
  pkgs,
  ...
}:
let
  # Restart the Quickshell bar in place (Mod+Shift+R). nixpkgs wraps the
  # launcher, so the process (comm) name is .quickshell-wra — match by
  # substring, NOT -x. Comm-only (no -f) so the cheatsheet watcher (a python3
  # process whose args mention qs) is never hit.
  shellRestart = pkgs.writeShellApplication {
    name = "shell-restart";
    runtimeInputs = [
      pkgs.procps
      pkgs.coreutils
    ];
    text = ''
      pkill quickshell || true
      sleep 0.3
      exec ${pkgs.quickshell}/bin/qs
    '';
  };

  # Hold-Super cheatsheet watcher: a read-only evdev reader (python-evdev) that
  # opens/closes the Quickshell cheatsheet over IPC. Reads the keyboard via a
  # scoped `uaccess` udev rule (NOT the `input` group) — see CLAUDE.md.
  superCheatWatch = pkgs.python3.withPackages (ps: [ ps.evdev ]);
  superCheatWatchCmd = "${superCheatWatch}/bin/python3 ${./super-cheatsheet-watch.py} ${pkgs.quickshell}/bin/qs";

  # Clipboard-history store filter, run by `wl-paste --watch` on every clipboard
  # change (content on stdin). Entries a password manager marks sensitive
  # (x-kde-passwordManagerHint — KeePassXC, Bitwarden, …) are skipped, so
  # secrets never land in cliphist's plaintext db (~/.cache/cliphist/db).
  clipStore = pkgs.writeShellApplication {
    name = "cliphist-store-filtered";
    runtimeInputs = [
      pkgs.wl-clipboard
      pkgs.cliphist
      pkgs.gnugrep
    ];
    text = ''
      if wl-paste --list-types | grep -qF x-kde-passwordManagerHint; then
        exit 0
      fi
      exec cliphist store
    '';
  };

  # Lock the session with the bar's CURRENT accent color. The Quickshell theme
  # persists the accent name to ~/.cache/quickshell/accent (Theme.qml,
  # runtime-switchable in the Control Center); map it to its Gruvbox hex and
  # override the ring colors of the static swaylock config
  # (../default.nix, programs.swaylock — blur, clock and the contrast colors
  # all come from there). Keep the case table in sync with Theme.qml's
  # `accents` map. All lock triggers (Mod+Escape, control-center button,
  # swayidle timeout, before-sleep) go through this wrapper.
  swaylockThemed = pkgs.writeShellApplication {
    name = "swaylock-themed";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      name=$(cat "''${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/accent" 2>/dev/null || echo blue)
      case "$name" in
        blue)   accent=458588 ;;
        aqua)   accent=689d6a ;;
        green)  accent=98971a ;;
        yellow) accent=d79921 ;;
        orange) accent=d65d0e ;;
        purple) accent=b16286 ;;
        red)    accent=cc241d ;;
        ivory)  accent=bdae93 ;;
        *)      accent=458588 ;;
      esac
      exec ${config.programs.swaylock.package}/bin/swaylock \
        --ring-color "$accent" --ring-ver-color "$accent" "$@"
    '';
  };

  # run-or-raise: focus the most-recently-focused window whose app_id matches the
  # regex (case-insensitive); if none exists, launch the command. Lets a single
  # keybind toggle between starting an app and jumping to it — handy for
  # single-instance apps (steam, signal, discord, …). niri + jq are baked in so
  # it doesn't depend on the session PATH.
  runOrRaise = pkgs.writeShellApplication {
    name = "run-or-raise";
    runtimeInputs = [
      pkgs.niri
      pkgs.jq
    ];
    text = ''
      re=$1; shift
      id=$(niri msg --json windows \
        | jq -r --arg re "$re" '[ .[] | select((.app_id // "") | test($re; "i")) ] | sort_by(.focus_timestamp.secs // 0) | (last // {}).id // empty')
      if [ -n "''${id:-}" ]; then
        exec niri msg action focus-window --id "$id"
      else
        exec "$@"
      fi
    '';
  };
in
{
  imports = [ ./clipboard.nix ];

  # niri has no built-in XWayland (unlike Hyprland). X11-only apps — chiefly
  # Steam (Valve's CEF client has no usable Wayland backend) — won't launch
  # without an X server. xwayland-satellite provides one; see settings.nix's
  # autostart block. (Discord runs native Wayland: the nixpkgs wrapper bakes in
  # --ozone-platform=wayland, so it no longer needs XWayland.)
  home.packages = [
    pkgs.niri
    pkgs.xwayland-satellite
    shellRestart
    swaylockThemed # lock triggers: binds.nix, ControlCenter.qml, swayidle
  ];

  # Assemble the KDL from the settings fragment followed by the keybinds block.
  xdg.configFile."niri/config.kdl".text =
    (import ./settings.nix {
      inherit
        pkgs
        config
        superCheatWatchCmd
        clipStore
        swaylockThemed
        ;
    })
    + (import ./binds.nix { inherit runOrRaise; });

  # Wayland session file for display managers.
  # greetd and SDDM ≥ 0.21 (configured with EnableHidpi/SessionDir pointing at
  # ~/.local/share/wayland-sessions) will pick this up automatically.
  # For SDDM on NixOS the canonical path is the system store — add
  # `programs.niri.enable = true` in ~/beehive to install the session file
  # system-wide and have it appear alongside Hyprland in the login screen.
  xdg.dataFile."wayland-sessions/niri.desktop".text = ''
    [Desktop Entry]
    Name=Niri
    Comment=A scrollable-tiling Wayland compositor
    Exec=niri
    Type=Application
  '';
}
