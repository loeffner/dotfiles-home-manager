// Tray menu ("traymenu"): the right-clicked tray item's menu, rendered from
// QsMenuOpener with submenu navigation (Back row inside a submenu). Checkable
// entries show a check; disabled ones are dimmed.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.island
import qs.services

IslandPanel {
    id: root
    panelId: "traymenu"
    panelWidth: 240

    QsMenuOpener {
        id: opener
        menu: TrayMenu.current
    }

    ListRow {
        Layout.fillWidth: true
        visible: TrayMenu.stack.length > 0
        implicitHeight: 26
        onClicked: TrayMenu.back()
        RowLayout {
            anchors { fill: parent; leftMargin: 6 }
            spacing: 4
            MIcon { text: "chevron_left"; size: 16; color: Theme.surfaceVariantText }
            MText { text: "Back"; Layout.fillWidth: true }
        }
    }

    Repeater {
        model: opener.children
        delegate: Item {
            id: item
            required property var modelData
            readonly property bool separator: modelData?.isSeparator ?? false
            Layout.fillWidth: true
            implicitHeight: separator ? 9 : 28

            Rectangle {
                visible: item.separator
                anchors.centerIn: parent
                width: parent.width - 12
                height: 1
                color: Theme.outline
                opacity: 0.5
            }
            ListRow {
                visible: !item.separator
                enabled: item.modelData?.enabled !== false
                anchors.fill: parent
                onClicked: {
                    const en = item.modelData;
                    if (en.hasChildren) {
                        TrayMenu.enter(en);
                    } else if (typeof en.triggered === "function") {
                        en.triggered();
                        root.close();
                    }
                }
                RowLayout {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    spacing: 6
                    MIcon {
                        visible: (item.modelData?.buttonType ?? 0) !== 0
                        text: item.modelData?.checkState === 2 ? "check" : ""
                        size: 15
                        Layout.preferredWidth: 16
                        color: Theme.primary
                    }
                    MText {
                        text: item.modelData?.text ?? ""
                        color: item.modelData?.enabled === false ? Theme.surfaceVariantText : Theme.surfaceText
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    MIcon {
                        visible: item.modelData?.hasChildren ?? false
                        text: "chevron_right"
                        size: 16
                        color: Theme.surfaceVariantText
                    }
                }
            }
        }
    }
}
