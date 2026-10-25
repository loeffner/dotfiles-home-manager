// StatusNotifier tray, folded behind a chevron by default (the chevron points the
// way it will move). Left-click raises the app's window via niri, falling back to
// its menu, then the SNI activate; right-click opens the menu (rendered by the
// "traymenu" panel); scrolling is forwarded to the item.
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import qs.config
import qs.components
import qs.services

Item {
    id: root
    required property var screen
    property bool expanded: false

    implicitWidth: row.implicitWidth
    implicitHeight: Theme.barHeight
    visible: SystemTray.items.values.length > 0

    function openMenu(item, anchor) {
        if (!item.hasMenu)
            return;
        TrayMenu.show(item);
        Popouts.open(screen, "traymenu", anchor);
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Theme.gap + 2

        MIcon {
            text: root.expanded ? "chevron_right" : "chevron_left"
            size: 18
            color: chevMa.containsMouse ? Theme.iconHover : Theme.surfaceVariantText
            scale: chevMa.containsMouse ? 1.15 : 1.0
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
            MouseArea {
                id: chevMa
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.expanded = !root.expanded
            }
        }

        // Icons fold out to the right of the chevron (width animates 0 ↔ natural).
        Item {
            clip: true
            implicitHeight: icons.implicitHeight
            Layout.preferredWidth: root.expanded ? icons.implicitWidth : 0
            opacity: root.expanded ? 1 : 0
            Behavior on Layout.preferredWidth { NumberAnimation { duration: 180; easing.type: Easing.OutQuart } }
            Behavior on opacity { NumberAnimation { duration: 150 } }

            RowLayout {
                id: icons
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                spacing: Theme.gap + 2

                Repeater {
                    model: SystemTray.items
                    delegate: Item {
                        id: entry
                        required property var modelData
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: 18
                        implicitHeight: 18
                        opacity: ma.containsMouse ? 1 : 0.9

                        Image {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            sourceSize: Qt.size(16, 16)
                            source: entry.modelData.icon
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }
                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: e => {
                                const it = entry.modelData;
                                if (e.button === Qt.RightButton)
                                    root.openMenu(it, entry);
                                else if (!Niri.focusByApp(it.id, it.title))
                                    it.hasMenu ? root.openMenu(it, entry) : it.activate();
                            }
                            onWheel: w => entry.modelData.scroll(w.angleDelta.y !== 0 ? w.angleDelta.y : w.angleDelta.x, w.angleDelta.x !== 0)
                        }
                    }
                }
            }
        }
    }
}
