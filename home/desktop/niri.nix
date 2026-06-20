{ config, pkgs, ... }:
let
  # Hold-Super cheatsheet watcher: a read-only evdev reader (python-evdev) that
  # opens/closes the Quickshell cheatsheet over IPC. Reads the keyboard via a
  # scoped `uaccess` udev rule (NOT the `input` group) — see CLAUDE.md.
  superCheatWatch = pkgs.python3.withPackages (ps: [ ps.evdev ]);
  superCheatWatchCmd =
    "${superCheatWatch}/bin/python3 ${./super-cheatsheet-watch.py} ${pkgs.quickshell}/bin/qs";
in
{
  # niri has no built-in XWayland (unlike Hyprland). X11-only apps — Steam,
  # and Electron apps like Discord that default to X11 — won't launch without
  # an X server. xwayland-satellite provides one; see the autostart block.
  home.packages = [
    pkgs.niri
    pkgs.xwayland-satellite
    pkgs.cliphist # clipboard-history store + decoder (the "Win+V" backend)
    pkgs.wl-clipboard # wl-copy / wl-paste — cliphist reads/writes via these
    pkgs.wtype # synthesizes the paste keystroke so the picker auto-pastes
  ];

  # Clipboard-history picker: a wofi menu over cliphist's stored history, bound
  # to Ctrl+Alt+V in the niri config below. The chosen entry is copied back onto
  # the clipboard and then pasted into the window that was focused before the
  # menu opened (Win+V style). Terminals paste with Ctrl+Shift+V and GUI apps
  # with Ctrl+V, so the focused window's app_id decides which to synthesize.
  # Guards against an empty/cancelled selection so Esc never clears the
  # clipboard or fires a stray paste.
  home.file.".local/bin/clipboard-picker" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      # Note the focused window now — wofi steals focus once it opens.
      focused=$(niri msg --json focused-window 2>/dev/null)

      sel=$(cliphist list | wofi --dmenu --prompt "Clipboard") || exit 0
      [ -z "$sel" ] && exit 0
      printf '%s\n' "$sel" | cliphist decode | wl-copy

      # Let niri hand focus back to that window, then synthesize its paste key.
      sleep 0.15
      if printf '%s' "$focused" \
        | grep -qiE '"app_id":[[:space:]]*"(kitty|foot|alacritty|wezterm|st|[Xx]?term[^"]*)"'; then
        wtype -M ctrl -M shift -k v -m shift -m ctrl   # terminals
      else
        wtype -M ctrl -k v -m ctrl                     # GUI default
      fi
    '';
  };

  # Niri compositor config — hand-written KDL (no home-manager module needed).
  # Reference: https://github.com/YaLTeR/niri/wiki/Configuration:-Overview
  xdg.configFile."niri/config.kdl".text = ''
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
    // Ctrl+Alt+V picker (below) has something to show. Absolute paths so it
    // starts regardless of PATH timing during session bring-up.
    spawn-at-startup "${pkgs.wl-clipboard}/bin/wl-paste" "--watch" "${pkgs.cliphist}/bin/cliphist" "store"

    // ── Keybinds ──────────────────────────────────────────────────────────
    //
    binds {
        // Discoverability & session. Mod+/ toggles the Quickshell pictographic
        // cheatsheet (the real trigger is hold-Super via keyd, see keyd.nix);
        // Mod+Shift+/ keeps niri's own textual overlay as a fallback.
        Mod+Slash       { spawn "qs" "ipc" "call" "cheatsheet" "toggle"; }
        Mod+Shift+Slash { show-hotkey-overlay; }      // niri's built-in cheat-sheet
        Ctrl+Alt+Delete { quit; }                      // safety net
        Mod+Shift+P     { power-off-monitors; }

        // MX Master thumb button (BTN_FORWARD, evdev 277) → overview.
        MouseForward repeat=false { toggle-overview; }

        // Apps — mirrors the Hyprland binds.
        Mod+Return    { spawn "kitty"; }
        Mod+B         { spawn "firefox"; }
        Mod+E         { spawn "kitty" "-e" "yazi"; }
        Mod+D         { spawn "discord"; }
        Mod+G         { spawn "steam"; }
        Mod+R         { spawn "sh" "-c" "pkill wofi || wofi --show drun"; }
        Mod+Space     { spawn "sh" "-c" "pkill wofi || wofi --show drun"; }
        Mod+Shift+R   { spawn "sh" "-c" "pkill quickshell && qs -d"; }

        // Window lifecycle.
        Mod+Q         { close-window; }
        Mod+Backspace { close-window; }
        Mod+Shift+F   { fullscreen-window; }           // Hyprland parity
        Mod+F         { maximize-column; }             // niri's "fullscreen-ish"

        // Overview — niri's signature zoomed-out workspace view.
        Mod+O repeat=false { toggle-overview; }

        // Focus (niri is column-based; K/J move within a column). hjkl + arrows.
        Mod+H     { focus-column-left; }
        Mod+L     { focus-column-right; }
        Mod+K     { focus-window-up; }
        Mod+J     { focus-window-down; }
        Mod+Left  { focus-column-left; }
        Mod+Right { focus-column-right; }
        Mod+Up    { focus-window-up; }
        Mod+Down  { focus-window-down; }
        Mod+Home  { focus-column-first; }
        Mod+End   { focus-column-last; }

        // Move windows/columns. Shift+hjkl (Hyprland parity) + Ctrl+arrows.
        Mod+Shift+H    { move-column-left; }
        Mod+Shift+L    { move-column-right; }
        Mod+Shift+K    { move-window-up; }
        Mod+Shift+J    { move-window-down; }
        Mod+Ctrl+Left  { move-column-left; }
        Mod+Ctrl+Right { move-column-right; }
        Mod+Ctrl+Up    { move-window-up; }
        Mod+Ctrl+Down  { move-window-down; }

        // Column composition — pull windows into / out of the current column.
        Mod+Comma        { consume-window-into-column; }
        Mod+Period       { expel-window-from-column; }
        Mod+BracketLeft  { consume-or-expel-window-left; }
        Mod+BracketRight { consume-or-expel-window-right; }
        Mod+W            { toggle-column-tabbed-display; }
        Mod+C            { center-column; }

        // Floating layer.
        Mod+V       { toggle-window-floating; }
        Mod+Shift+V { switch-focus-between-floating-and-tiling; }

        // Clipboard history — Win+V-style popup of past clipboard entries
        // (cliphist + wofi). On Ctrl+Alt+V so it stays clear of kitty's own
        // Ctrl+Shift+V paste. Pressing it again closes an already-open picker.
        Ctrl+Alt+V { spawn "sh" "-c" "pkill wofi || $HOME/.local/bin/clipboard-picker"; }

        // Workspaces 1-5: switch and move active column.
        Mod+1 { focus-workspace 1; }
        Mod+2 { focus-workspace 2; }
        Mod+3 { focus-workspace 3; }
        Mod+4 { focus-workspace 4; }
        Mod+5 { focus-workspace 5; }
        Mod+Shift+1 { move-column-to-workspace 1; }
        Mod+Shift+2 { move-column-to-workspace 2; }
        Mod+Shift+3 { move-column-to-workspace 3; }
        Mod+Shift+4 { move-column-to-workspace 4; }
        Mod+Shift+5 { move-column-to-workspace 5; }

        // Workspace navigation — page keys and Mod+scroll.
        Mod+Page_Down { focus-workspace-down; }
        Mod+Page_Up   { focus-workspace-up; }
        Mod+Shift+Page_Down { move-column-to-workspace-down; }
        Mod+Shift+Page_Up   { move-column-to-workspace-up; }
        // Mod+vertical scroll → workspaces; Mod+horizontal scroll → columns.
        Mod+WheelScrollDown  cooldown-ms=150 { focus-workspace-down; }
        Mod+WheelScrollUp    cooldown-ms=150 { focus-workspace-up; }
        Mod+WheelScrollLeft  cooldown-ms=150 { focus-column-left; }
        Mod+WheelScrollRight cooldown-ms=150 { focus-column-right; }
        Mod+Shift+WheelScrollLeft  cooldown-ms=150 { move-column-left; }
        Mod+Shift+WheelScrollRight cooldown-ms=150 { move-column-right; }

        // Column width: fine adjust, preset cycle, and fixed shortcuts.
        Mod+Minus      { set-column-width "-10%"; }
        Mod+Equal      { set-column-width "+10%"; }
        Mod+0          { set-column-width "80%"; }  // Super+) → 80% (8 cols)

        // Volume (allow-when-locked keeps media keys working on the lock screen).
        XF86AudioRaiseVolume allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+"; }
        XF86AudioLowerVolume allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
        XF86AudioMute        allow-when-locked=true { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
        XF86AudioMicMute     allow-when-locked=true { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle"; }

        // Volume + media on the function row (this keyboard has no media keys).
        // The Quickshell OSD reacts to the resulting Pipewire / MPRIS state.
        Mod+F1 { spawn "wpctl" "set-mute"   "@DEFAULT_AUDIO_SINK@" "toggle"; }
        Mod+F2 { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
        Mod+F3 { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+"; }
        Mod+F7 { spawn "playerctl" "previous"; }
        Mod+F8 { spawn "playerctl" "play-pause"; }
        Mod+F9 { spawn "playerctl" "next"; }

        // Screenshots.
        Print      { screenshot; }
        Ctrl+Print { screenshot-screen; }
        Alt+Print  { screenshot-window; }
    }
  '';

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
