// Notification bell + center. The bell shows a dot for unread history and opens
// a panel grouping notifications by app. Each entry is a raised card (for visual
// separation) that can be swiped away, shows the sending app's actions while the
// notification is still alive, and can be cleared individually. Groups collapse
// to the latest; per-app mute and clear live in the group header. Right-click the
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
            width: 5; height: 5; radius: 3
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
        popWidth: 380

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
                    onClicked: Qt.callLater(() => Notifications.clearAll())
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

                    Item {
                        implicitWidth: 18; implicitHeight: 18
                        Image {
                            id: gIcon
                            anchors.fill: parent
                            source: Notifications.iconSource(group.items[0])
                            sourceSize.width: 18; sourceSize.height: 18
                            fillMode: Image.PreserveAspectFit
                            visible: status === Image.Ready
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: gIcon.status !== Image.Ready
                            text: "󰂚"; color: Theme.dim
                            font.family: Theme.font; font.pixelSize: Theme.iconSize
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
                    Text {
                        text: Notifications.isMuted(group.modelData.appName) ? "󰂛" : "󰂚"
                        color: Notifications.isMuted(group.modelData.appName) ? Theme.accent : (muteMa.containsMouse ? Theme.fg : Theme.dim)
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        Behavior on color { ColorAnimation { duration: 80 } }
                        MouseArea {
                            id: muteMa
                            anchors.fill: parent; anchors.margins: -3
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Notifications.toggleMute(group.modelData.appName)
                        }
                    }
                    Text {
                        text: "󰅖"
                        color: grpClearMa.containsMouse ? Theme.urgent : Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        Behavior on color { ColorAnimation { duration: 80 } }
                        MouseArea {
                            id: grpClearMa
                            anchors.fill: parent; anchors.margins: -3
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { const a = group.modelData.appName; Qt.callLater(() => Notifications.clearApp(a)); }
                        }
                    }
                }

                // ── Entry cards (collapsed to the latest unless expanded) ───
                Repeater {
                    model: group.expanded ? group.items : group.items.slice(0, 1)

                    // Wrapper holds the layout slot; the card slides for swipe.
                    delegate: Item {
                        id: entry
                        required property var modelData
                        readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
                        readonly property var acts: Notifications.actionsFor(modelData.id)
                        Layout.fillWidth: true
                        Layout.leftMargin: 12
                        implicitHeight: card.implicitHeight

                        Rectangle {
                            id: card
                            width: parent.width
                            implicitHeight: ecol.implicitHeight + Theme.pad
                            radius: Theme.radius - 2
                            color: Theme.bgPopup
                            border.width: 1
                            border.color: entry.critical ? Theme.urgent : Theme.border

                            // Left stripe for depth / urgency cue.
                            Rectangle {
                                anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                width: 3
                                topLeftRadius: card.radius
                                bottomLeftRadius: card.radius
                                color: entry.critical ? Theme.urgent : Theme.accent
                                opacity: entry.critical ? 1.0 : 0.6
                            }

                            // Swipe to dismiss (below the action/clear hit areas).
                            // Tracks the pointer against the stable wrapper (so the
                            // moving card doesn't feed back) and commits the fling
                            // mid-drag once past the threshold — the pointer can then
                            // leave the small popup surface without aborting it.
                            MouseArea {
                                id: swipe
                                anchors.fill: parent
                                preventStealing: true
                                cursorShape: Qt.PointingHandCursor
                                property real startX: 0
                                property bool committed: false
                                property bool dragging: false
                                onPressed: e => { startX = mapToItem(entry, e.x, 0).x; committed = false; dragging = false; }
                                onPositionChanged: e => {
                                    if (committed) return;
                                    const dx = mapToItem(entry, e.x, 0).x - startX;
                                    if (Math.abs(dx) > 4) dragging = true;
                                    card.x = dx;
                                    card.opacity = Math.max(0.15, 1 - Math.abs(dx) / entry.width);
                                    if (Math.abs(dx) > 64) {
                                        committed = true;
                                        efling.to = dx > 0 ? entry.width + 40 : -entry.width - 40;
                                        efling.start();
                                    }
                                }
                                // A tap (not a swipe) jumps to the producing window and
                                // closes the center; a drag just snaps back.
                                onReleased: {
                                    if (committed)
                                        return;
                                    if (!dragging) {
                                        if (Niri.focusByApp(entry.modelData.desktopEntry, entry.modelData.appName))
                                            popup.hide();
                                    } else {
                                        esnap.start();
                                    }
                                }
                            }
                            NumberAnimation {
                                id: efling; target: card; property: "x"; duration: 140; easing.type: Easing.InQuart
                                // Defer the model change: removing the entry destroys
                                // this delegate, which must not happen inside its own
                                // animation callback (use-after-free).
                                onFinished: { const id = entry.modelData.id; Qt.callLater(() => Notifications.removeById(id)); }
                            }
                            NumberAnimation {
                                id: esnap; target: card; property: "x"; to: 0; duration: 120; easing.type: Easing.OutQuart
                                onStarted: card.opacity = 1
                            }

                            ColumnLayout {
                                id: ecol
                                anchors { left: parent.left; right: parent.right; top: parent.top }
                                anchors { leftMargin: Theme.pad; rightMargin: Theme.gap; topMargin: Theme.gap }
                                spacing: 2

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: entry.modelData.summary
                                        color: entry.critical ? Theme.urgent : Theme.fg
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: Qt.formatTime(new Date(entry.modelData.time), "HH:mm")
                                        color: Theme.dim
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize - 2
                                    }
                                    Text {
                                        text: "󰅖"
                                        color: itemClearMa.containsMouse ? Theme.urgent : Theme.dim
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize - 1
                                        Behavior on color { ColorAnimation { duration: 80 } }
                                        MouseArea {
                                            id: itemClearMa
                                            anchors.fill: parent; anchors.margins: -4
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: { const id = entry.modelData.id; Qt.callLater(() => Notifications.removeById(id)); }
                                        }
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    visible: (entry.modelData.body ?? "") !== ""
                                    text: entry.modelData.body
                                    color: Theme.dim
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize - 1
                                    wrapMode: Text.WordWrap
                                    textFormat: Text.MarkdownText
                                    maximumLineCount: group.expanded ? 6 : 2
                                    elide: Text.ElideRight
                                }

                                // Live action buttons (empty once the notif is gone).
                                Flow {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 2
                                    visible: entry.acts.length > 0
                                    spacing: Theme.gap
                                    Repeater {
                                        model: entry.acts
                                        delegate: Rectangle {
                                            required property var modelData
                                            implicitWidth: aLabel.implicitWidth + Theme.pad * 2
                                            implicitHeight: aLabel.implicitHeight + Theme.gap
                                            radius: Theme.radius - 4
                                            color: aMa.containsMouse ? Theme.bg2 : Theme.bg1
                                            Behavior on color { ColorAnimation { duration: 80 } }
                                            Text {
                                                id: aLabel
                                                anchors.centerIn: parent
                                                text: modelData.text
                                                color: Theme.fg
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontSize - 1
                                            }
                                            MouseArea {
                                                id: aMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    modelData.invoke();
                                                    const id = entry.modelData.id;
                                                    Qt.callLater(() => Notifications.removeById(id));
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Expand / collapse toggle for multi-entry groups.
                Text {
                    visible: group.modelData.count > 1
                    Layout.leftMargin: 12
                    text: group.expanded ? "Show less" : ("Show " + (group.modelData.count - 1) + " more")
                    color: moreMa.containsMouse ? Theme.fg : Theme.accent
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 2
                    Behavior on color { ColorAnimation { duration: 80 } }
                    MouseArea {
                        id: moreMa
                        anchors.fill: parent; anchors.margins: -3
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: group.expanded = !group.expanded
                    }
                }
            }
        }
    }
}
