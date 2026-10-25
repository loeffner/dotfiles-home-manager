// Scene: the new bar over the real one (same spot), screenshotted for comparison
// with dev/scenes/bar-old.qml (--old).
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.bar
import qs.dev

ShellRoot {
    Bar {
        modelData: Quickshell.screens[0]
        exclusionMode: ExclusionMode.Ignore
    }
    Snap { name: "bar-left"; region: "0,0 900x30"; delay: 1800 }
    Snap { name: "bar-centre"; region: "1420,0 600x30"; delay: 1800 }
    Snap { name: "bar-right"; region: "2940,0 500x30"; delay: 1800 }
    Quit { delay: 2300 }
}
