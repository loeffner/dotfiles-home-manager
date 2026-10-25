pragma Singleton

// The hold-Super keybind cheatsheet's visibility, driven over IPC by the evdev
// watcher (niri/super-cheatsheet-watch.py) and the Mod+/ toggle:
//   qs ipc call cheatsheet open|close|toggle
// Opening closes any open popout. (Not named `show`: it collides with the
// `qs ipc show` verb.)
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool shown: false

    onShownChanged: if (shown)
        Popouts.close()

    IpcHandler {
        target: "cheatsheet"
        function open(): string {
            root.shown = true;
            return "ok";
        }
        function close(): string {
            root.shown = false;
            return "ok";
        }
        function toggle(): string {
            root.shown = !root.shown;
            return "ok";
        }
    }
}
