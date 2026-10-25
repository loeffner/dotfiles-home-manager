// Workspaces of this bar's output: the focused one is a wide accent pill with a
// soft glow halo, the others small dots (the active-but-unfocused one brighter).
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

RowLayout {
    id: root
    required property var screen
    spacing: Theme.gap

    Repeater {
        model: Niri.workspacesOn(root.screen?.name ?? "")

        delegate: Item {
            id: ws
            required property var modelData
            implicitWidth: modelData.focused ? 22 : 10
            implicitHeight: 18
            Behavior on implicitWidth { NumberAnimation { duration: 80; easing.type: Easing.OutQuart } }

            Rectangle {
                visible: ws.modelData.focused
                anchors.centerIn: parent
                width: parent.implicitWidth + 10
                height: 20
                radius: height / 2
                color: Theme.primary
                opacity: 0.18
            }
            Rectangle {
                anchors.centerIn: parent
                width: parent.implicitWidth
                height: 8
                radius: 4
                color: ws.modelData.focused ? Theme.primary : ws.modelData.active ? Theme.surfaceVariantText : Theme.surfaceContainerHighest
                Behavior on color { ColorAnimation { duration: 80 } }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Niri.focusWorkspace(ws.modelData.idx)
                }
            }
        }
    }
}
