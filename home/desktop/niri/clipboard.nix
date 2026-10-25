# Clipboard history tooling. The store daemon (`wl-paste --watch` + the filtered
# store, see ./default.nix) is autostarted from ./settings.nix; the picker is the
# Quickshell clipboard panel (Mod+X in ./binds.nix).
{ pkgs, ... }:
{
  home.packages = [
    # The Quickshell clipboard panel (shell/services/Clip.qml) shells out to
    # these: cliphist + wl-copy to list/decode/copy, wtype to type the paste
    # keystroke when an entry is picked (shell/scripts/clip-paste.sh).
    pkgs.cliphist
    pkgs.wl-clipboard
    pkgs.wtype
  ];
}
