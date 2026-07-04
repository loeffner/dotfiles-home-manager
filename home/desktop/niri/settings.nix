# niri compositor settings — the KDL fragment that precedes the keybinds block
# (see ./binds.nix): input, layout, environment, and autostart. Assembled into
# the final config.kdl by ./default.nix.
{
  pkgs,
  config,
  superCheatWatchCmd,
  shellSwitch,
  clipStore,
}:
''
  input {
      keyboard {
          xkb {
              // English (US) is the default; German is the alternate. Toggle
              // with Mod+Alt+Space (see binds.nix → switch-layout). The bar
              // shows a "DE" indicator whenever the non-default layout is active.
              layout "us,de"
          }
          repeat-delay 200
          repeat-rate 30
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
      default-column-width { proportion 0.4; }

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

  // ── Window Rules ─────────────────────────────────────────────────────────

  // Firefox draws its own 1px dark frame inside the window, which obscures one
  // pixel of niri's border (making the active border look thinner and muted).
  // clip-to-geometry clips that self-drawn edge so niri's full 2px border shows.
  window-rule {
    match app-id=r#"firefox$"#
    clip-to-geometry true
  }

  window-rule {
    match app-id=r#"firefox$"# title="^Picture-in-Picture|Library$"
    open-floating true
  }

  window-rule {
    match app-id="^hms-runner$"
    open-floating true
    default-column-width { fixed 900; }
    default-window-height { fixed 550; }
  }

  window-rule {
    match app-id="^luajit$"
    match title="KOReader$"
    default-column-width { fixed 900; }
  }

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

  spawn-at-startup "${pkgs.swaybg}/bin/swaybg" "-i" "${config.home.homeDirectory}/Pictures/earth.png" "-m" "fill"

  // Quickshell desktop shell. `restore` relaunches the last-selected shell
  // (custom / dms), defaulting to the custom config on first run.
  // Switch at runtime with Mod+Shift+S (see binds.nix).
  spawn-at-startup "${shellSwitch}/bin/shell-switch" "restore"

  // Hold-Super cheatsheet watcher (evdev -> qs ipc). Wrapped in a restart loop
  // so a transient device hiccup (suspend/unplug) re-enumerates keyboards.
  spawn-at-startup "sh" "-c" "while true; do ${superCheatWatchCmd}; sleep 2; done"

  // Clipboard-history daemon: record clipboard changes so the Ctrl+Alt+V
  // picker (see binds.nix) has something to show. The filtered store skips
  // entries password managers mark sensitive (see default.nix). Absolute paths
  // so it starts regardless of PATH timing during session bring-up.
  spawn-at-startup "${pkgs.wl-clipboard}/bin/wl-paste" "--watch" "${clipStore}/bin/cliphist-store-filtered"

  // Idle management. swayidle arms each timeout from the last input event:
  // after 10 min blank the monitors (niri's DPMS; any key/mouse powers them
  // back on, and `resume` makes that explicit), after 30 min suspend the box.
  // niri honours the idle-inhibit protocol, so fullscreen video (mpv, browser)
  // that inhibits idle pauses these timers — no special-casing needed. -w makes
  // swayidle wait for each command so they can't overlap.
  spawn-at-startup "${pkgs.swayidle}/bin/swayidle" "-w" \
      "timeout" "600"  "${pkgs.niri}/bin/niri msg action power-off-monitors" \
      "resume"         "${pkgs.niri}/bin/niri msg action power-on-monitors" \
      "timeout" "1800" "${pkgs.systemd}/bin/systemctl suspend"
''
