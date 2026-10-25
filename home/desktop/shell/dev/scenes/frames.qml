// Scene: island render timing — logs every frame the island window swaps after
// a panel opens (ms since the open), to find stalls. PANEL env picks the panel.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.bar
import qs.island
import qs.panels
import qs.services

ShellRoot {
    id: shell
    readonly property var scr: Quickshell.screens[0]
    readonly property string panel: Quickshell.env("PANEL") || "clipboard"
    property double t0: 0
    property int frames: 0

    Bar { id: bar; modelData: shell.scr; exclusionMode: ExclusionMode.Ignore }
    Island {
        id: island
        modelData: shell.scr
        ClipboardPanel {}
        ControlPanel {}
        ClockPanel {}
        IslandPanel {
            panelId: "dummy"
            panelWidth: 300
            Rectangle { implicitWidth: 260; implicitHeight: 200; color: "gray" }
        }
    }
    Connections {
        target: island.contentItem.Window.window
        function onFrameSwapped() {
            shell.frames++;
            if (shell.t0 > 0 && shell.frames <= 40)
                console.log("TEST frame " + shell.frames + " +" + (Date.now() - shell.t0) + "ms p=" + island.progress.toFixed(2));
        }
    }
    Timer {
        running: true
        interval: 600
        onTriggered: {
            shell.t0 = Date.now();
            shell.frames = 0;
            Popouts.open(shell.scr, shell.panel, bar.triggers[shell.panel] ?? bar.triggers.clock);
        }
    }
    Timer { running: true; interval: 2200; onTriggered: { console.log("TEST total frames=" + shell.frames); Qt.exit(0); } }
}
