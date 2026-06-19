// Workspace indicator: a row of pills. The focused workspace is a wide accent
// pill; other occupied workspaces are small grey dots. Click to focus.
import QtQuick
import QtQuick.Layouts
import Quickshell

RowLayout {
    spacing: Theme.gap

    Repeater {
        model: Niri.workspaces

        delegate: Rectangle {
            required property var modelData

            implicitWidth: modelData.focused ? 22 : 10
            implicitHeight: 8
            radius: 4
            color: modelData.focused ? Theme.accent : modelData.active ? Theme.dim : Theme.bg2

            Behavior on implicitWidth {
                NumberAnimation {
                    duration: 80
                    easing.type: Easing.OutQuart
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: 80
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Niri.focusWorkspace(modelData.idx)
            }
        }
    }
}
