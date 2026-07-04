// Tray — StatusNotifier system tray. The SNI activate()/display() calls are
// unreliable here, so: left-click raises the app's window via niri (falling back
// to its menu / activate), right-click opens the item's menu, which we render
// ourselves from QsMenuOpener (the way DankMaterialShell does) with submenu
// navigation. Scrolling forwards to the item.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

Item {
    id: root
    required property var bar

    implicitWidth: row.implicitWidth
    implicitHeight: Theme.barHeight
    visible: SystemTray.items.values.length > 0

    // Menu navigation: menuHandle is the item's root menu; menuStack holds pushed
    // submenu entries. currentMenu is what the opener shows.
    property var menuHandle: null
    property Item menuAnchor: null
    property var menuStack: []
    readonly property var currentMenu: menuStack.length > 0 ? menuStack[menuStack.length - 1] : menuHandle

    QsMenuOpener {
        id: opener
        menu: root.currentMenu
    }

    function openMenu(it, anchorItem) {
        if (!it.hasMenu)
            return;
        root.menuStack = [];
        root.menuHandle = it.menu;
        root.menuAnchor = anchorItem;
        menuPop.open();
    }

    // Tray icons are collapsed behind a chevron by default; click to fold out.
    property bool open: false

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Theme.gap + 2

        // Chevron sits on the LEFT and points the way it will move:
        // left = fold out, right = fold in.
        MIcon {
            text: root.open ? "chevron_right" : "chevron_left"
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
                onClicked: root.open = !root.open
            }
        }

        // Folding container: icons fold out to the RIGHT of the chevron. Width
        // animates between 0 and the icons' natural width; icons stay left-
        // aligned so they reveal/collapse toward the chevron.
        Item {
            id: foldWrap
            clip: true
            implicitHeight: icons.implicitHeight
            Layout.preferredWidth: root.open ? icons.implicitWidth : 0
            opacity: root.open ? 1 : 0
            Behavior on Layout.preferredWidth { NumberAnimation { duration: 180; easing.type: Easing.OutQuart } }
            Behavior on opacity { NumberAnimation { duration: 150 } }

            RowLayout {
                id: icons
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
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
                            sourceSize.width: 16
                            sourceSize.height: 16
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
                                if (e.button === Qt.RightButton) {
                                    root.openMenu(it, entry);
                                } else if (!Niri.focusByApp(it.id, it.title)) {
                                    // No matching window: open its menu, else the SNI action.
                                    if (it.hasMenu)
                                        root.openMenu(it, entry);
                                    else
                                        it.activate();
                                }
                            }
                            onWheel: w => entry.modelData.scroll(w.angleDelta.y !== 0 ? w.angleDelta.y : w.angleDelta.x, w.angleDelta.x !== 0)
                        }
                    }
                }
            }
        }
    }

    // ── Rendered tray menu ───────────────────────────────────────────────────
    Popout {
        id: menuPop
        bar: root.bar
        anchorItem: root.menuAnchor ? root.menuAnchor : root
        popId: "traymenu"
        popWidth: 240

        // Back row (visible inside a submenu).
        Rectangle {
            Layout.fillWidth: true
            visible: root.menuStack.length > 0
            implicitHeight: 26
            radius: Theme.radiusS
            color: backMa.containsMouse ? Theme.surfaceContainer : "transparent"
            RowLayout {
                anchors { fill: parent; leftMargin: 6 }
                spacing: 4
                MIcon { text: "chevron_left"; size: 16; color: Theme.surfaceVariantText }
                Text {
                    text: "Back"
                    color: Theme.surfaceText
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    Layout.fillWidth: true
                }
            }
            MouseArea {
                id: backMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.menuStack = root.menuStack.slice(0, -1)
            }
        }

        Repeater {
            model: opener.children

            delegate: Item {
                id: mrow
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: modelData && modelData.isSeparator ? 9 : 28

                // Separator
                Rectangle {
                    visible: mrow.modelData && mrow.modelData.isSeparator
                    anchors.centerIn: parent
                    width: parent.width - 12
                    height: 1
                    color: Theme.outline
                    opacity: 0.5
                }

                // Entry
                Rectangle {
                    visible: !(mrow.modelData && mrow.modelData.isSeparator)
                    anchors.fill: parent
                    radius: Theme.radiusS
                    color: mma.containsMouse ? Theme.surfaceContainer : "transparent"

                    RowLayout {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                        spacing: 6
                        MIcon {
                            visible: mrow.modelData && mrow.modelData.buttonType !== undefined && mrow.modelData.buttonType !== 0
                            text: (mrow.modelData && mrow.modelData.checkState === 2) ? "check" : ""
                            size: 15
                            Layout.preferredWidth: (mrow.modelData && mrow.modelData.buttonType) ? 16 : 0
                            color: Theme.primary
                        }
                        Text {
                            text: (mrow.modelData && mrow.modelData.text) || ""
                            color: (mrow.modelData && mrow.modelData.enabled === false) ? Theme.surfaceVariantText : Theme.surfaceText
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        MIcon {
                            visible: mrow.modelData && mrow.modelData.hasChildren
                            text: "chevron_right"
                            size: 16
                            color: Theme.surfaceVariantText
                        }
                    }

                    MouseArea {
                        id: mma
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: mrow.modelData && !mrow.modelData.isSeparator && (mrow.modelData.enabled !== false)
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const en = mrow.modelData;
                            if (en.hasChildren) {
                                root.menuStack = [...root.menuStack, en];
                            } else if (typeof en.triggered === "function") {
                                en.triggered();
                                menuPop.close();
                            }
                        }
                    }
                }
            }
        }
    }
}
