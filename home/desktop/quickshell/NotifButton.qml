// Notification bell: shows a dot when there's unread history, opens a panel with
// the notification log grouped by app. Each group has an icon, a count, a per-app
// mute toggle and a clear-group action; each entry can be cleared individually,
// and groups with more than one entry collapse to the latest. Right-click the
// bell toggles DND.
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

        // Header.
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
                visible: Notifications.dnd
                text: "DND"
                color: Theme.warn
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 2
                font.bold: true
            }
            Text {
                visible: root.count > 0
                text: "Clear all"
                color: clearAllMa.containsMouse ? Theme.fg : Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                Behavior on color { ColorAnimation { duration: 80 } }
                MouseArea {
                    id: clearAllMa
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
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

        // One block per app.
        Repeater {
            model: Notifications.grouped()

            delegate: ColumnLayout {
                id: group
                required property var modelData
                property bool expanded: false
                readonly property var items: modelData.items
                Layout.fillWidth: true
                spacing: 4

                // ── Group header ────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.gap

                    // App icon (falls back to a bell glyph).
                    Item {
                        implicitWidth: 18
                        implicitHeight: 18
                        Image {
                            id: gIcon
                            anchors.fill: parent
                            source: Notifications.iconSource(group.items[0])
                            sourceSize.width: 18
                            sourceSize.height: 18
                            fillMode: Image.PreserveAspectFit
                            visible: status === Image.Ready
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: gIcon.status !== Image.Ready
                            text: "󰂚"
                            color: Theme.dim
                            font.family: Theme.font
                            font.pixelSize: Theme.iconSize
                        }
                    }

                    Text {
                        text: group.modelData.appName || "Unknown"
                        color: Theme.fg
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        visible: group.modelData.count > 1
                        text: "×" + group.modelData.count
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 1
                    }
                    // Per-app mute toggle.
                    Text {
                        text: Notifications.isMuted(group.modelData.appName) ? "󰂛" : "󰂚"
                        color: Notifications.isMuted(group.modelData.appName) ? Theme.accent : (muteMa.containsMouse ? Theme.fg : Theme.dim)
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        Behavior on color { ColorAnimation { duration: 80 } }
                        MouseArea {
                            id: muteMa
                            anchors.fill: parent
                            anchors.margins: -3
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Notifications.toggleMute(group.modelData.appName)
                        }
                    }
                    // Clear this app's entries.
                    Text {
                        text: "󰅖"
                        color: grpClearMa.containsMouse ? Theme.urgent : Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        Behavior on color { ColorAnimation { duration: 80 } }
                        MouseArea {
                            id: grpClearMa
                            anchors.fill: parent
                            anchors.margins: -3
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Notifications.clearApp(group.modelData.appName)
                        }
                    }
                }

                // ── Entries (collapsed to the latest unless expanded) ───────
                Repeater {
                    model: group.expanded ? group.items : group.items.slice(0, 1)

                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.leftMargin: 24
                        spacing: Theme.gap

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: modelData.summary
                                    color: modelData.urgency === NotificationUrgency.Critical ? Theme.urgent : Theme.fg
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: Qt.formatTime(new Date(modelData.time), "HH:mm")
                                    color: Theme.dim
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize - 2
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: (modelData.body ?? "") !== ""
                                text: modelData.body
                                color: Theme.dim
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize - 1
                                wrapMode: Text.WordWrap
                                textFormat: Text.MarkdownText
                                maximumLineCount: group.expanded ? 6 : 2
                                elide: Text.ElideRight
                            }
                        }

                        // Per-entry clear.
                        Text {
                            text: "󰅖"
                            color: itemClearMa.containsMouse ? Theme.urgent : Theme.dim
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 2
                            Layout.alignment: Qt.AlignTop
                            Behavior on color { ColorAnimation { duration: 80 } }
                            MouseArea {
                                id: itemClearMa
                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Notifications.removeById(modelData.id)
                            }
                        }
                    }
                }

                // Expand / collapse toggle for multi-entry groups.
                Text {
                    visible: group.modelData.count > 1
                    Layout.leftMargin: 24
                    text: group.expanded ? "Show less" : ("Show " + (group.modelData.count - 1) + " more")
                    color: moreMa.containsMouse ? Theme.fg : Theme.accent
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 2
                    Behavior on color { ColorAnimation { duration: 80 } }
                    MouseArea {
                        id: moreMa
                        anchors.fill: parent
                        anchors.margins: -3
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: group.expanded = !group.expanded
                    }
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
