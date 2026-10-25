// Clipboard panel ("clipboard", Mod+X): history (refreshed on open) with pins
// floating to the top, filterable by type and searchable. Picking an entry —
// click, or j/k then Enter — inserts it into the window you came from (copy +
// paste, Clip.paste); right-click only copies it. The pin toggles pinning, d
// deletes an entry (a pin is unpinned); the trash wipes cliphist history (pins
// are kept). Images get lazily decoded thumbnails. Keys: IslandPanel's rules.
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
    searchField: search

    property int typeFilter: 0 // 0 All, 1 Text, 2 Images
    property int current: 0 // the entry Enter inserts (j/k move it)

    onOpened: {
        search.clear();
        current = 0;
        Clip.refresh();
    }
    onEntriesChanged: current = Math.max(0, Math.min(current, entries.length - 1))

    function insert(entry) {
        Clip.paste(entry);
        close();
    }
    function copyOnly(entry) {
        Clip.copy(entry);
        close();
    }

    // ── Keyboard (IslandPanel: "?" shows this) ───────────────────────────────
    shortcuts: [
        {
            "title": "Clipboard",
            "keys": [
                [["Tab", "⇧Tab"], "All / Text / Images"],
                [["j", "k"], "Move down / up"],
                [["Enter", "Space"], "Insert into your window"],
                [["p"], "Pin / unpin"],
                [["d", "Del"], "Delete (unpin a pin)"]
            ]
        }
    ]
    function handleKey(e) {
        const entry = entries[current];
        switch (e.key) {
        case Qt.Key_Tab:
        case Qt.Key_Backtab:
            typeFilter = (typeFilter + 3 + tabStep(e)) % 3;
            return true;
        case Qt.Key_J:
        case Qt.Key_Down:
            current = Math.min(entries.length - 1, current + 1);
            return true;
        case Qt.Key_K:
        case Qt.Key_Up:
            current = Math.max(0, current - 1);
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            if (entry)
                insert(entry);
            return true;
        case Qt.Key_P:
            if (entry)
                Clip.togglePin(entry);
            return true;
        case Qt.Key_D:
        case Qt.Key_Delete:
            if (entry)
                Clip.remove(entry);
            return true;
        }
        return false;
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
        onTextChanged: root.current = 0
        onAccepted: if (root.entries[root.current])
            root.insert(root.entries[root.current])
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
        id: list
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 380)
        visible: root.entries.length > 0
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        spacing: 2
        currentIndex: root.current
        highlightFollowsCurrentItem: false
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
        model: ScriptModel {
            objectProp: "uid"
            values: root.entries
        }

        delegate: ListRow {
            id: row
            required property var modelData
            required property int index
            readonly property bool pinned: Clip.isPinned(modelData)
            property string thumb: ""

            width: ListView.view.width
            implicitHeight: modelData.isImage ? 42 : 30
            selected: index === root.current
            onClicked: root.insert(modelData)
            onRightClicked: root.copyOnly(modelData)
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

    MText {
        visible: root.entries.length > 0
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: "Click or Enter inserts  ·  right-click copies  ·  ? for shortcuts"
        sizeDelta: -3
        muted: true
    }
}
