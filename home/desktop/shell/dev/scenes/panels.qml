// Scene: the whole shell; opens each panel in turn and screenshots it at rest.
// Twin of dev/scenes/panels-old.qml (--old) — same timeline and regions.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.bar
import qs.island
import qs.panels
import qs.services
import qs.dev

ShellRoot {
    id: shell
    readonly property var scr: Quickshell.screens[0]
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
        id: bar
        modelData: shell.scr
        exclusionMode: ExclusionMode.Ignore
    }
    Island {
        id: island
        modelData: shell.scr
        ControlPanel {}
        ConfirmPanel {}
        NotificationsPanel {}
        ClipboardPanel {}
        ProcessesPanel {}
        ClockPanel {}
        TrayMenuPanel {}
    }

    Timer {
        interval: 1300
        running: true
        repeat: true
        triggeredOnStart: false
        onTriggered: {
            shell.step++;
            if (shell.step >= shell.order.length) {
                Qt.exit(0);
                return;
            }
            const id = shell.order[shell.step];
            Popouts.open(shell.scr, id, bar.triggers[id]); // as a click would
            snap.name = id;
            snap.region = shell.regions[id];
            snap.restart();
        }
    }
    Timer {
        interval: 1300
        running: true
        repeat: true
        Component.onCompleted: start()
        onTriggered: console.log("TEST state open=" + Popouts.current(shell.scr) + " shown=" + island._shownId + " p=" + island.progress.toFixed(2) + " alive=" + island._alive + " x=" + island.shownX.toFixed(0) + " w=" + island.shownW.toFixed(0) + " h=" + island.shownH.toFixed(0))
    }
    Snap {
        id: snap
        running: false
        delay: 900
    }
}
