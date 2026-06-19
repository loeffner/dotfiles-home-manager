// The top bar (one PanelWindow per screen). Reserves its height via the
// layershell exclusive zone so niri tiles below it. Three regions: workspaces
// (left), clock (centre), status cluster (right).
import QtQuick
import QtQuick.Layouts
import Quickshell

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

    Clock {
        anchors.centerIn: parent
    }

    RowLayout {
        anchors {
            right: parent.right
            rightMargin: Theme.pad
            verticalCenter: parent.verticalCenter
        }
        spacing: Theme.pad

        Media {
            id: media
            bar: bar
        }
        Sep {
            visible: media.visible
        }
        Audio {
            bar: bar
        }
        Sep {}
        Network {
            bar: bar
        }
        Sep {}
        NotifButton {
            bar: bar
        }
        Sep {}
        // Power button — opens the full-screen session modal.
        Text {
            text: "󰐦"
            font.family: Theme.font
            font.pixelSize: Theme.iconSize
            color: Theme.dim
            Layout.alignment: Qt.AlignVCenter

            opacity: pwrMa.containsMouse ? 1.0 : 0.7
            Behavior on opacity { NumberAnimation { duration: 120 } }

            MouseArea {
                id: pwrMa
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ShellState.powerOpen = !ShellState.powerOpen
            }
        }
    }
}
