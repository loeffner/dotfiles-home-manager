# niri compositor — hand-written KDL config (no home-manager module needed).
# Split by concern: ./settings.nix (input/layout/env/autostart) and ./binds.nix
# (keybinds) are assembled into config.kdl below; ./clipboard.nix carries the
# Win+V clipboard picker. Reference:
# https://github.com/YaLTeR/niri/wiki/Configuration:-Overview
{ config, pkgs, ... }:
let
  # Hold-Super cheatsheet watcher: a read-only evdev reader (python-evdev) that
  # opens/closes the Quickshell cheatsheet over IPC. Reads the keyboard via a
  # scoped `uaccess` udev rule (NOT the `input` group) — see CLAUDE.md.
  superCheatWatch = pkgs.python3.withPackages (ps: [ ps.evdev ]);
  superCheatWatchCmd =
    "${superCheatWatch}/bin/python3 ${./super-cheatsheet-watch.py} ${pkgs.quickshell}/bin/qs";

  # run-or-raise: focus the most-recently-focused window whose app_id matches the
  # regex (case-insensitive); if none exists, launch the command. Lets a single
  # keybind toggle between starting an app and jumping to it — handy for
  # single-instance apps (steam, signal, discord, …). niri + jq are baked in so
  # it doesn't depend on the session PATH.
  runOrRaise = pkgs.writeShellApplication {
    name = "run-or-raise";
    runtimeInputs = [ pkgs.niri pkgs.jq ];
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

  # niri has no built-in XWayland (unlike Hyprland). X11-only apps — Steam, and
  # Electron apps like Discord that default to X11 — won't launch without an X
  # server. xwayland-satellite provides one; see settings.nix's autostart block.
  home.packages = [
    pkgs.niri
    pkgs.xwayland-satellite
  ];

  # Assemble the KDL from the settings fragment followed by the keybinds block.
  xdg.configFile."niri/config.kdl".text =
    (import ./settings.nix { inherit pkgs config superCheatWatchCmd; })
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
