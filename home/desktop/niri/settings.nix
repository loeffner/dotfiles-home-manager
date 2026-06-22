# niri compositor settings — the KDL fragment that precedes the keybinds block
# (see ./binds.nix): input, layout, environment, and autostart. Assembled into
# the final config.kdl by ./default.nix.
{ pkgs, config, superCheatWatchCmd }:
''
  input {
      keyboard {
          xkb {
              // Layout inherited from the system; override here if needed.
          }
          repeat-delay 600
          repeat-rate 25
      }
      touchpad {
          tap
          natural-scroll
      }
  }
  layout {
      gaps 5
      center-focused-column "never"
      always-center-single-column
      preset-column-widths {
          proportion 0.33333
          proportion 0.5
          proportion 0.66667
      }
      default-column-width { proportion 0.5; }

      // Active border: warm earth-ivory (matches bar accent). Inactive: dark.
      border {
          width 2
          active-color "#bdae93"
          inactive-color "#3c3836"
      }
      focus-ring {
          off
      }
  }

  prefer-no-csd

  screenshot-path "~/Pictures/Screenshots/%Y-%m-%d-%H-%M-%S.png"

  animations {}

  // ── Environment ─────────────────────────────────────────────────────────

  // Point X11 clients at the display xwayland-satellite creates (see below).
  // niri also pushes this into the systemd/D-Bus activation environment, so
  // apps launched via .desktop files (e.g. Discord, Steam) inherit it too.
  environment {
      DISPLAY ":0"
  }

  // ── Autostart ─────────────────────────────────────────────────────────

  // XWayland for X11-only apps (Steam) and X11-by-default Electron (Discord).
  // Pinned to :0 to match the DISPLAY exported above. Absolute path so it
  // starts regardless of PATH timing during session bring-up.
  spawn-at-startup "${pkgs.xwayland-satellite}/bin/xwayland-satellite" ":0"

  spawn-at-startup "swaybg" "-i" "${config.home.homeDirectory}/Pictures/earth.png" "-m" "fill"

  spawn-at-startup "${pkgs.quickshell}/bin/qs"

  // Hold-Super cheatsheet watcher (evdev -> qs ipc). Wrapped in a restart loop
  // so a transient device hiccup (suspend/unplug) re-enumerates keyboards.
  spawn-at-startup "sh" "-c" "while true; do ${superCheatWatchCmd}; sleep 2; done"

  // Clipboard-history daemon: record every clipboard change so the
  // Ctrl+Alt+V picker (see binds.nix) has something to show. Absolute paths so
  // it starts regardless of PATH timing during session bring-up.
  spawn-at-startup "${pkgs.wl-clipboard}/bin/wl-paste" "--watch" "${pkgs.cliphist}/bin/cliphist" "store"
''
