# niri compositor — hand-written KDL config (no home-manager module needed).
# Split by concern: ./settings.nix (input/layout/env/autostart) and ./binds.nix
# (keybinds) are assembled into config.kdl below; ./clipboard.nix carries the
# Win+V clipboard picker. Reference:
# https://github.com/YaLTeR/niri/wiki/Configuration:-Overview
{
  config,
  pkgs,
  dms,
  ...
}:
let
  inherit (pkgs) lib;
  system = pkgs.stdenv.hostPlatform.system;

  # Runtime switcher between the custom shell and DankMaterialShell. Remembers
  # the choice in a state file so the niri autostart (`shell-switch restore`)
  # brings back the last-used shell; `pick` shows a wofi menu (Mod+Shift+S),
  # `use <name>` sets one directly. Stops whatever is running (only one shell at
  # a time) and launches the chosen one detached. dms runs its own bundled
  # quickshell from the store; `custom` is the hand-written config in
  # ../quickshell launched with bare `qs`.
  shellSwitch = pkgs.writeShellApplication {
    name = "shell-switch";
    runtimeInputs = [
      pkgs.wofi
      pkgs.procps
      pkgs.util-linux
      pkgs.coreutils
    ];
    text = ''
      state="''${XDG_STATE_HOME:-$HOME/.local/state}/current-shell"

      launch() {
        case "$1" in
          custom) setsid -f ${pkgs.quickshell}/bin/qs                       >/dev/null 2>&1 ;;
          dms)    setsid -f ${lib.getExe dms.packages.${system}.default} run >/dev/null 2>&1 ;;
          *) echo "shell-switch: unknown shell '$1'" >&2; return 1 ;;
        esac
      }

      stop_all() {
        # nixpkgs wraps the launchers, so the process (comm) names are
        # .quickshell-wra / .dms-wrapped — match by substring, NOT -x. Comm-only
        # (no -f) so the cheatsheet watcher (a python3 process whose args mention
        # qs) is never hit. `custom`'s qs execs quickshell, so it shares the
        # .quickshell-wra name. Two passes: killing the dms supervisor first
        # stops it respawning its quickshell child.
        for _ in 1 2; do
          pkill dms        || true
          pkill quickshell || true
          sleep 0.3
        done
      }

      switch_to() {
        mkdir -p "$(dirname "$state")"
        printf '%s\n' "$1" > "$state"
        stop_all
        launch "$1"
      }

      case "''${1:-restore}" in
        use)     switch_to "''${2:?usage: shell-switch use <custom|dms>}" ;;
        pick)    choice=$(printf 'custom\ndms\n' | wofi --dmenu --prompt 'Shell')
                 [ -n "$choice" ] && switch_to "$choice" ;;
        restore) stop_all; launch "$(cat "$state" 2>/dev/null || echo custom)" ;;
        *) echo "usage: shell-switch [pick|use <name>|restore]" >&2; exit 1 ;;
      esac
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
    shellSwitch
    swaylockThemed # lock triggers: binds.nix, ControlCenter.qml, swayidle
  ];

  # Assemble the KDL from the settings fragment followed by the keybinds block.
  xdg.configFile."niri/config.kdl".text =
    (import ./settings.nix {
      inherit
        pkgs
        config
        superCheatWatchCmd
        shellSwitch
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
