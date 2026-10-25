#!/bin/sh
# The paste half of services/Clip.paste() (Win+V style): the entry is already
# on the clipboard; once the popout has closed and niri has handed keyboard
# focus back to the window, type that window's paste key. Needs wtype.
#   clip-paste.sh terminal   Ctrl+Shift+V (terminals: Ctrl+V is a control char)
#   clip-paste.sh app        Ctrl+V
sleep 0.3
if [ "$1" = terminal ]; then
  wtype -M ctrl -M shift -k v -m shift -m ctrl
else
  wtype -M ctrl -k v -m ctrl
fi
