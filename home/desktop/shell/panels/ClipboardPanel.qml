// Clipboard panel ("clipboard"): history (refreshed on open) with pins floating
// to the top, filterable by type and searchable (the search box is focused on
// open). Click an entry to copy it back; the pin toggles pinning; the trash wipes
// cliphist history (pins are kept). Images get lazily decoded thumbnails.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.island
import qs.services

IslandPanel {
    id: root
    panelId: "clipboard"
    panelWidth: 400

    property int typeFilter: 0 // 0 All, 1 Text, 2 Images

    onOpened: {
        search.clear();
        Clip.refresh();
        Qt.callLater(() => search.focusInput());
    }

    readonly property var entries: {
        const q = search.text.toLowerCase();
        const ok = e => (typeFilter === 0 || (typeFilter === 1) === !e.isImage) && (!q || e.preview.toLowerCase().indexOf(q) >= 0);
        return Clip.pins.filter(ok).concat(Clip.history.filter(e => ok(e) && !Clip.isPinned(e)));
    }

    PanelHeader {
        icon: "content_paste"
        title: "Clipboard"
        MIconButton {
            icon: "delete"
            visible: Clip.history.length > 0
            raised: true
            activeColor: Theme.urgent
            onClicked: Clip.wipe()
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 4
        Repeater {
            model: ["All", "Text", "Images"]
            delegate: MButton {
                required property string modelData
                required property int index
                Layout.fillWidth: true
                label: modelData
                filled: root.typeFilter === index
                onClicked: root.typeFilter = index
            }
        }
    }

    MTextField {
        id: search
        Layout.fillWidth: true
        icon: "search"
        placeholder: "Search clipboard"
    }

    MText {
        visible: root.entries.length === 0
        Layout.fillWidth: true
        Layout.topMargin: Theme.pad
        Layout.bottomMargin: Theme.pad
        text: "Nothing here"
        muted: true
        horizontalAlignment: Text.AlignHCenter
    }

    ListView {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 380)
        visible: root.entries.length > 0
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        spacing: 2
        model: ScriptModel {
            objectProp: "uid"
            values: root.entries
        }

        delegate: ListRow {
            id: row
            required property var modelData
            readonly property bool pinned: Clip.isPinned(modelData)
            property string thumb: ""

            width: ListView.view.width
            implicitHeight: modelData.isImage ? 42 : 30
            onClicked: {
                Clip.copy(modelData);
                root.close();
            }
            Component.onCompleted: if (modelData.isImage)
                Clip.thumbnail(modelData, url => row.thumb = url)

            RowLayout {
                anchors { fill: parent; leftMargin: 8; rightMargin: 6 }
                spacing: Theme.gap

                Rectangle {
                    visible: row.modelData.isImage
                    implicitWidth: 46
                    implicitHeight: 30
                    radius: 4
                    color: Theme.surfaceContainerHigh
                    clip: true
                    Image {
                        id: thumbImg
                        anchors.fill: parent
                        source: row.thumb
                        sourceSize: Qt.size(92, 60)
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready
                    }
                    MIcon {
                        anchors.centerIn: parent
                        visible: thumbImg.status !== Image.Ready
                        text: "image"
                        size: 16
                        color: Theme.surfaceVariantText
                    }
                }
                MText {
                    text: row.modelData.preview
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                MIcon {
                    text: "push_pin"
                    fill: row.pinned
                    size: 15
                    Layout.preferredWidth: 22
                    color: row.pinned ? Theme.primary : Theme.surfaceVariantText
                    opacity: row.hovered || row.pinned ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 110 } }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -3
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Clip.togglePin(row.modelData)
                    }
                }
            }
        }
    }
}
