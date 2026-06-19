// Notification bell: shows a dot when there's unread history, opens a panel
// with the full notification log. Right-click toggles DND.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

Item {
    id: root
    required property var bar

    readonly property int count: Notifications.history.length

    implicitWidth: row.implicitWidth
    implicitHeight: Theme.barHeight

    opacity: ma.containsMouse ? 1.0 : 0.82
    Behavior on opacity { NumberAnimation { duration: 70 } }

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 4

        Text {
            text: Notifications.dnd ? "󰂛" : "󰂚"
            font.family: Theme.font
            font.pixelSize: Theme.iconSize
            color: Notifications.dnd ? Theme.dim : Theme.fg
        }
        // Unread dot — shown when there are history entries.
        Rectangle {
            visible: root.count > 0 && !Notifications.dnd
            width: 5
            height: 5
            radius: 3
            color: Theme.accent
            Layout.alignment: Qt.AlignVCenter
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: e => {
            if (e.button === Qt.RightButton)
                Notifications.dnd = !Notifications.dnd;
            else
                popup.toggle();
        }
    }

    BarPopup {
        id: popup
        bar: root.bar
        anchorItem: root
        popWidth: 360

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Notifications"
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                font.bold: true
                Layout.fillWidth: true
            }
            Text {
                visible: root.count > 0
                text: "Clear"
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Notifications.dismissAll();
                        Notifications.clearHistory();
                    }
                }
            }
        }

        Text {
            visible: root.count === 0
            text: "No notifications"
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }

        Repeater {
            model: Notifications.history

            delegate: ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: (modelData.appName ? modelData.appName : "") + (modelData.appName && modelData.summary ? "  " : "") + modelData.summary
                        color: modelData.urgency === NotificationUrgency.Critical ? Theme.urgent : Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: Qt.formatTime(modelData.time, "HH:mm")
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 1
                    }
                }
                Text {
                    Layout.fillWidth: true
                    visible: modelData.body !== ""
                    text: modelData.body
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    wrapMode: Text.WordWrap
                    textFormat: Text.MarkdownText
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Theme.border
                    opacity: 0.5
                }
            }
        }
    }
}
