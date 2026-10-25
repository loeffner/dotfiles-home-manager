// The top bar of one screen. Reserves its height (layershell exclusive zone) so
// niri tiles below it, and never takes keyboard focus. Left: workspaces +
// minimap. Centre: the clock pinned to the exact centre, flanked by mail + the
// bell and the play button (anchored to it, so it never moves). Right: keyboard
// layout · tray · clipboard · system · control pill. Clicking empty bar space
// closes this screen's popout.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.overlays
import qs.services

PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barHeight
    color: Theme.bar
    WlrLayershell.namespace: "quickshell-bar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // The item each panel hangs from (what a click on it passes to Popouts).
    readonly property var triggers: ({
            "control": controlPill,
            "notifications": bell,
            "mail": mailBtn,
            "clipboard": clipIcon,
            "processes": sysIcon,
            "clock": clock
        })

    MouseArea {
        anchors.fill: parent
        enabled: Popouts.current(bar.modelData) !== ""
        onClicked: Popouts.close(bar.modelData)
    }

    RowLayout {
        anchors { left: parent.left; leftMargin: Theme.pad; verticalCenter: parent.verticalCenter }
        spacing: Theme.pad
        Workspaces { screen: bar.modelData }
        Sep { visible: minimap.visible }
        Minimap { id: minimap; screen: bar.modelData }
    }

    Clock {
        id: clock
        screen: bar.modelData
        anchors.centerIn: parent
    }
    NotifBell {
        id: bell
        screen: bar.modelData
        anchors { right: clock.left; rightMargin: Theme.pad + 6; verticalCenter: parent.verticalCenter }
    }
    MailButton {
        id: mailBtn
        screen: bar.modelData
        anchors { right: bell.left; rightMargin: Theme.pad + 6; verticalCenter: parent.verticalCenter }
    }
    MediaButton {
        anchors { left: clock.right; leftMargin: Theme.pad + 6; verticalCenter: parent.verticalCenter }
    }

    RowLayout {
        anchors { right: parent.right; rightMargin: Theme.pad; verticalCenter: parent.verticalCenter }
        spacing: Theme.pad

        KbLayout { id: kbl }
        Sep { visible: kbl.visible }
        Tray { id: tray; screen: bar.modelData }
        Sep { visible: tray.visible }
        BarIcon {
            id: clipIcon
            icon: "content_paste"
            active: Popouts.isOpen(bar.modelData, "clipboard")
            onClicked: Popouts.toggle(bar.modelData, "clipboard", clipIcon)
        }
        Sep {}
        BarIcon {
            id: sysIcon
            icon: "monitoring"
            active: Popouts.isOpen(bar.modelData, "processes")
            colorOverride: SystemStats.cpu > 0.85 && !active ? Theme.urgent : undefined
            onClicked: Popouts.toggle(bar.modelData, "processes", sysIcon)
        }
        Sep {}
        ControlPill {
            id: controlPill
            screen: bar.modelData
        }
    }

    VolumeOsd {
        modelData: bar.modelData
        anchorItem: controlPill
    }
}
