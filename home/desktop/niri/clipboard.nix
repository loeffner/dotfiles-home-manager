# Clipboard-history picker: a wofi menu over cliphist's stored history, bound to
# Ctrl+Alt+V in ./binds.nix. The store daemon (`wl-paste --watch cliphist store`)
# is autostarted from ./settings.nix; this module ships the picker script and the
# tools it needs.
{ pkgs, ... }:
{
  home.packages = [
    pkgs.cliphist # clipboard-history store + decoder (the "Win+V" backend)
    pkgs.wl-clipboard # wl-copy / wl-paste — cliphist reads/writes via these
    pkgs.wtype # synthesizes the paste keystroke so the picker auto-pastes
  ];

  # The chosen entry is copied back onto the clipboard and then pasted into the
  # window that was focused before the menu opened (Win+V style). Terminals paste
  # with Ctrl+Shift+V and GUI apps with Ctrl+V, so the focused window's app_id
  # decides which to synthesize. Guards against an empty/cancelled selection so
  # Esc never clears the clipboard or fires a stray paste.
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
}
