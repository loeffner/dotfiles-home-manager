// Scene: the bar's left side (workspaces + minimap), snapped at 1x and
// upscaled for inspection.
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
    Snap { name: "minimap"; region: "0,0 400x30"; delay: 3500 }
    Quit { delay: 4000 }
}
