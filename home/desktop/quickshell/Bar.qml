// The top bar (one PanelWindow per screen). Reserves its height via the
// layershell exclusive zone so niri tiles below it. Three regions: workspaces
// (left), clock (centre), status cluster (right).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    color: Theme.bar

    // Instantiate Sound at launch so its global volume-feedback watcher is active
    // from the start (not only after the first notification references it).
    Component.onCompleted: Sound.volumeFeedback

    // The bar itself never takes keyboard focus. The cluster popouts
    // (PopoutManager / Popout.qml) own their own layer surfaces and grab
    // EXCLUSIVE focus only for text fields — see Popout.qml. Any layer surface
    // that holds keyboard focus makes niri consume the first outside-click as a
    // focus transfer (a two-click dismiss); keeping the bar focus-free makes
    // every dismiss click land immediately.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Click empty bar area (not an icon) to dismiss an open cluster popout, DMS-
    // style. Below the bar widgets in z, so icons still handle their own clicks.
    MouseArea {
        anchors.fill: parent
        enabled: PopoutManager.anyOpen
        onClicked: PopoutManager.close()
    }

    RowLayout {
        anchors {
            left: parent.left
            leftMargin: Theme.pad
            verticalCenter: parent.verticalCenter
        }
        spacing: Theme.pad

        Workspaces {}
        Sep {
            visible: minimap.visible
        }
        Minimap {
            id: minimap
        }
    }

    // Centre: the clock is pinned to the exact centre of the bar and never
    // moves. Notifications flank it on the left, the now-playing play/pause
    // glyph on the right — both anchored to the clock so its position is fixed
    // regardless of whether they're present.
    Clock {
        id: clock
        bar: bar
        anchors.centerIn: parent
    }
    NotifCenter {
        bar: bar
        anchors.right: clock.left
        anchors.rightMargin: Theme.pad + 6
        anchors.verticalCenter: parent.verticalCenter
    }
    Media {
        id: media
        anchors.left: clock.right
        anchors.leftMargin: Theme.pad + 6
        anchors.verticalCenter: parent.verticalCenter
    }

    RowLayout {
        anchors {
            right: parent.right
            rightMargin: Theme.pad
            verticalCenter: parent.verticalCenter
        }
        spacing: Theme.pad

        // Keyboard-layout badge (only on a non-default layout) sits to the left
        // of the M3 cluster.
        KbLayout {
            id: kbl
        }
        Sep {
            visible: kbl.visible
        }

        // ── DMS-grade cluster: tray · clipboard · system · bell · control ─────
        // Audio + network live inside the Control Center now; session power lives
        // in its header. (Old Audio/Network/power-glyph widgets removed.)
        Tray {
            id: tray
            bar: bar
        }
        Sep {
            visible: tray.visible
        }
        Clipboard {
            bar: bar
        }
        Sep {}
        SysPill {
            bar: bar
        }
        Sep {}
        ControlCenter {
            bar: bar
        }
    }
}
