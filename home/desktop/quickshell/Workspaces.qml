// Workspace indicator: a row of pills. The focused workspace is a wide accent
// pill with a soft glow halo (atmosphere effect); inactive ones are small dots.
import QtQuick
import QtQuick.Layouts
import Quickshell

RowLayout {
    spacing: Theme.gap

    Repeater {
        model: Niri.workspaces

        delegate: Item {
            required property var modelData
            // Outer Item is larger than the pill to give the glow room.
            implicitWidth: modelData.focused ? 22 : 10
            implicitHeight: 18

            Behavior on implicitWidth {
                NumberAnimation { duration: 80; easing.type: Easing.OutQuart }
            }

            // Glow halo — only on the focused pill.
            Rectangle {
                visible: parent.modelData.focused
                anchors.centerIn: parent
                width: parent.implicitWidth + 10
                height: 10 + 10
                radius: height / 2
                color: Theme.primary
                opacity: 0.18
            }

            // The pill itself.
            Rectangle {
                anchors.centerIn: parent
                width: parent.implicitWidth
                height: 8
                radius: 4
                color: parent.modelData.focused ? Theme.primary
                     : parent.modelData.active  ? Theme.surfaceVariantText
                     :                            Theme.surfaceContainerHighest

                Behavior on color { ColorAnimation { duration: 80 } }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Niri.focusWorkspace(parent.parent.modelData.idx)
                }
            }
        }
    }
}
