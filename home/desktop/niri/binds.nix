# niri keybinds — the KDL `binds { … }` block. Assembled after ./settings.nix
# into the final config.kdl by ./default.nix. `runOrRaise` is the run-or-raise
# helper (focus an existing window or launch the app); everything else resolves
# from the session PATH.
{ runOrRaise }:
''
  // ── Keybinds ──────────────────────────────────────────────────────────
  //
  binds {
      // Discoverability & session. Mod+/ toggles the Quickshell pictographic
      // cheatsheet (the real trigger is hold-Super via the evdev watcher);
      // Mod+Shift+/ keeps niri's own textual overlay as a fallback.
      Mod+Slash       { spawn "qs" "ipc" "call" "cheatsheet" "toggle"; }
      Mod+Shift+Slash { show-hotkey-overlay; }      // niri's built-in cheat-sheet
      Ctrl+Alt+Delete { quit; }                      // safety net
      Mod+Escape      { spawn "swaylock"; }          // lock the session
      Mod+Shift+P     { power-off-monitors; }

      // Cycle keyboard layout (us → de → us). The bar shows "DE" when active.
      Mod+Alt+Space   { switch-layout "next"; }

      // Apps — mirrors the Hyprland binds.
      Mod+Return    { spawn "kitty"; }
      Mod+E         { spawn "kitty" "-e" "yazi"; }
      // run-or-raise: jump to the app if it's already running, else launch it.
      Mod+B         { spawn "${runOrRaise}/bin/run-or-raise" "^firefox$" "firefox"; }
      Mod+D         { spawn "${runOrRaise}/bin/run-or-raise" "^discord$" "discord"; }
      Mod+G         { spawn "${runOrRaise}/bin/run-or-raise" "^steam$" "steam"; }
      Mod+S         { spawn "${runOrRaise}/bin/run-or-raise" "^signal$" "signal-desktop"; }
      Mod+N         { spawn "${runOrRaise}/bin/run-or-raise" "^zennotes$" "zennotes-desktop"; }
      Mod+Y         { spawn "${runOrRaise}/bin/run-or-raise" "^geeqie$" "geeqie"; }
      Mod+U         { spawn "${runOrRaise}/bin/run-or-raise" "^darktable$" "darktable"; }
      Mod+R         { spawn "sh" "-c" "pkill wofi || wofi --show drun"; }
      Mod+Space     { spawn "sh" "-c" "pkill wofi || wofi --show drun"; }
      Mod+Shift+S   { spawn "shell-switch" "pick"; }     // wofi menu: custom/dms
      Mod+Shift+R   { spawn "shell-switch" "restore"; }  // restart the current shell
      Mod+Ctrl+R    { spawn "kitty" "--app-id" "hms-runner" "-e" "bash" "-c" "home-manager switch --flake ~/dotfiles#terra; echo; read -rp 'Press Enter to close...'"; }

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
      // Up/down within the column; at the column edge, cross to the adjacent
      // workspace (handy when columns mostly hold a single window).
      Mod+K     { focus-window-or-workspace-up; }
      Mod+J     { focus-window-or-workspace-down; }
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
      Ctrl+Alt+V { spawn "sh" "-c" "pkill wofi || clipboard-picker"; }

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
      Mod+9          { set-column-width "20%"; }  // Super+( → 20% (2 cols)
      Mod+8          { set-column-width "50%"; }  // Super+* → 50% (5 cols)

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
''
