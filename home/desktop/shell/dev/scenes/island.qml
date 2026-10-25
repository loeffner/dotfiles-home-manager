// Scene: the Island morph — open panel A (centre), switch to panel B (snaps to
// the right edge), close. Screenshots mid-open, open, mid-switch, switched,
// mid-close.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.island
import qs.services
import qs.dev

ShellRoot {
    id: shell
    property var scr: Quickshell.screens[0]

    PanelWindow {
        id: bar
        screen: shell.scr
        anchors { top: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        implicitHeight: Theme.barHeight
        color: Theme.bar
        MText { id: mid; anchors.centerIn: parent; text: "Sat 24 Oct   17:44" }
        MIcon { id: right; anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter } text: "volume_up"; size: 18 }
    }

    // Bright backdrop (below the island: mapped first, same layer) so the
    // shape and its flares are clearly visible in screenshots.
    PanelWindow {
        screen: shell.scr
        anchors { top: true; left: true; right: true }
        margins.top: Theme.barHeight
        exclusionMode: ExclusionMode.Ignore
        implicitHeight: 360
        color: "#7a9a5a"
    }

    Island {
        modelData: shell.scr
        IslandPanel {
            panelId: "a"
            panelWidth: 420
            PanelHeader { icon: "calendar_month"; title: "Panel A" }
            MButton { Layout.fillWidth: true; label: "A button" }
            Rectangle { Layout.fillWidth: true; implicitHeight: 120; color: Theme.surfaceContainer; radius: Theme.radiusM }
        }
        IslandPanel {
            panelId: "b"
            panelWidth: 300
            PanelHeader { icon: "tune"; title: "Panel B (edge)" }
            Rectangle { Layout.fillWidth: true; implicitHeight: 220; color: Theme.surfaceContainer; radius: Theme.radiusM }
        }
    }

    Timer { running: true; interval: 500; onTriggered: Popouts.open(shell.scr, "a", mid) }
    Snap { name: "1-opening"; region: "1300,0 840x260"; delay: 560 }
    Snap { name: "2-open"; region: "1300,0 840x260"; delay: 1100 }
    Timer { running: true; interval: 1400; onTriggered: Popouts.open(shell.scr, "b", right) }
    Snap { name: "3-switching"; region: "1300,0 2140x320"; delay: 1500 }
    Snap { name: "4-switched"; region: "2940,0 500x320"; delay: 2100 }
    Timer { running: true; interval: 2400; onTriggered: Popouts.close(shell.scr) }
    Snap { name: "5-closing"; region: "2940,0 500x320"; delay: 2480 }
    Snap { name: "6-closed"; region: "2940,0 500x320"; delay: 2900 }
    Quit { delay: 3300 }
}
