// Scene (--old): the previous bar, same spot and snaps as dev/scenes/bar.qml.

import QtQuick
import Quickshell
import Quickshell.Wayland



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
