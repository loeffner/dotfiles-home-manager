// Scene (--old): the previous shell's bar; opens each popout in turn with the
// same timeline and screenshot regions as dev/scenes/panels.qml.
import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
    id: shell
    readonly property var order: ["control", "notifications", "clipboard", "processes", "clock"]
    readonly property var regions: ({
            "control": "2840,0 600x720",
            "notifications": "1300,0 840x560",
            "clipboard": "2840,0 600x720",
            "processes": "2840,0 600x720",
            "clock": "1300,0 840x560"
        })
    property int step: -1

    Bar {
        modelData: Quickshell.screens[0]
        exclusionMode: ExclusionMode.Ignore
    }
    Timer {
        interval: 1300
        running: true
        repeat: true
        onTriggered: {
            shell.step++;
            if (shell.step >= shell.order.length) {
                Qt.exit(0);
                return;
            }
            const id = shell.order[shell.step];
            PopoutManager.open(id);
            snap.name = id;
            snap.region = shell.regions[id];
            snap.restart();
        }
    }
    Snap {
        id: snap
        running: false
        delay: 900
    }
}
