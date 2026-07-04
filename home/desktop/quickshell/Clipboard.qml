// Clipboard — history via cliphist (the store daemon runs from niri). Searchable,
// filterable by type (All / Text / Images / Pinned), with image thumbnails and
// pinning (pins persist via ClipStore). Click an entry to copy it back; the pin
// icon pins/unpins; the trash icon wipes cliphist history (pins are kept).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
    required property var bar

    property var entries: [] // [{ id, preview, isImage, mime }]
    property int typeFilter: 0 // 0 All, 1 Text, 2 Images
    readonly property string thumbDir: (Quickshell.env("HOME") || "") + "/.cache/quickshell/clip-thumbs"

    implicitWidth: icon.implicitWidth
    implicitHeight: Theme.barHeight

    // Pinned clips always float to the top (deduped from the history list), then
    // the regular cliphist entries — both honouring the type filter + search.
    readonly property var shown: {
        const q = search.text.toLowerCase();
        const okType = e => root.typeFilter === 0 || (root.typeFilter === 1 && !e.isImage) || (root.typeFilter === 2 && e.isImage);
        const okSearch = e => !q || e.preview.toLowerCase().indexOf(q) >= 0;
        const pins = ClipStore.pins.filter(p => okType(p) && okSearch(p));
        const rest = root.entries.filter(e => okType(e) && okSearch(e) && !ClipStore.isPinned(e.preview));
        return pins.concat(rest);
    }

    function copy(id) {
        Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" | wl-copy', "_", String(id)]);
    }
    function wipe() {
        Quickshell.execDetached(["cliphist", "wipe"]);
        root.entries = [];
    }

    MIcon {
        id: icon
        anchors.centerIn: parent
        text: "content_paste"
        size: 20
        fill: pop.isOpen
        color: pop.isOpen ? Theme.primary : (ma.containsMouse ? Theme.iconHover : Theme.surfaceText)
        scale: ma.containsMouse ? 1.15 : 1.0
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pop.toggle()
    }

    Connections {
        target: pop
        function onIsOpenChanged() {
            if (pop.isOpen) {
                search.clear();
                listProc.running = true;
                Qt.callLater(() => search.focusInput());
            }
        }
    }

    Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    if (!line)
                        continue;
                    const i = line.indexOf("\t");
                    if (i < 0)
                        continue;
                    const id = line.slice(0, i);
                    const raw = line.slice(i + 1);
                    const m = raw.match(/binary data .*?\b(png|jpe?g|gif|webp|bmp|tiff)\b\s+(\d+x\d+)/i);
                    if (m) {
                        const t = m[1].toLowerCase();
                        out.push({
                                    "id": id,
                                    "preview": "Image · " + m[2],
                                    "isImage": true,
                                    "mime": "image/" + (t === "jpg" ? "jpeg" : t)
                                });
                    } else {
                        out.push({
                                    "id": id,
                                    "preview": raw.replace(/\s+/g, " ").trim(),
                                    "isImage": false,
                                    "mime": ""
                                });
                    }
                }
                root.entries = out;
            }
        }
    }

    Popout {
        id: pop
        bar: root.bar
        anchorItem: root
        popId: "clipboard"
        popWidth: 400
        keyboardOnOpen: true

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gap
            MIcon { text: "content_paste"; size: 18; color: Theme.primary }
            Text {
                text: "Clipboard"
                color: Theme.surfaceText
                font.family: Theme.font
                font.pixelSize: Theme.fontSize + 1
                font.bold: true
                Layout.fillWidth: true
            }
            MIconButton {
                icon: "delete"
                visible: root.entries.length > 0
                raised: true
                activeColor: Theme.urgent
                onClicked: root.wipe()
            }
        }

        // Type filter
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            Repeater {
                model: ["All", "Text", "Images"]
                delegate: MButton {
                    required property var modelData
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

        Text {
            visible: root.shown.length === 0
            Layout.fillWidth: true
            Layout.topMargin: Theme.pad
            Layout.bottomMargin: Theme.pad
            text: "Nothing here"
            color: Theme.surfaceVariantText
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            horizontalAlignment: Text.AlignHCenter
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 380)
            visible: root.shown.length > 0
            clip: true
            model: root.shown
            boundsBehavior: Flickable.StopAtBounds
            spacing: 2

            delegate: Rectangle {
                id: crow
                required property var modelData
                readonly property bool isPin: modelData.key !== undefined
                readonly property bool img: modelData.isImage === true
                readonly property bool pinned: crow.isPin || ClipStore.isPinned(modelData.preview)
                readonly property bool hovered: crowHover.hovered

                width: ListView.view.width
                implicitHeight: crow.img ? 42 : 30
                radius: Theme.radiusS
                color: crow.hovered ? Theme.surfaceContainer : Theme.surface
                Behavior on color { ColorAnimation { duration: 110 } }

                HoverHandler { id: crowHover }

                // Lazily decode a thumbnail for cliphist image entries (pins point
                // straight at their stored file).
                property string thumbSrc: crow.isPin ? ("file://" + modelData.file) : ""
                Process {
                    id: dec
                    command: ["sh", "-c", 'mkdir -p "$1"; f="$1/$2"; [ -s "$f" ] || cliphist decode "$2" > "$f"; echo "$f"', "_", root.thumbDir, String(crow.modelData.id)]
                    stdout: StdioCollector {
                        onStreamFinished: crow.thumbSrc = "file://" + text.trim()
                    }
                }
                Component.onCompleted: if (crow.img && !crow.isPin)
                    dec.running = true

                RowLayout {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 6 }
                    spacing: Theme.gap

                    Rectangle {
                        visible: crow.img
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: 46
                        implicitHeight: 30
                        radius: 4
                        color: Theme.surfaceContainerHigh
                        clip: true
                        Image {
                            id: thumbImg
                            anchors.fill: parent
                            source: crow.thumbSrc
                            sourceSize.width: 92
                            sourceSize.height: 60
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
                    Text {
                        text: crow.modelData.preview
                        color: Theme.surfaceText
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    MIcon {
                        text: "push_pin"
                        fill: crow.pinned
                        size: 15
                        Layout.preferredWidth: 22
                        horizontalAlignment: Text.AlignHCenter
                        color: crow.pinned ? Theme.primary : Theme.surfaceVariantText
                        opacity: crow.hovered || crow.pinned ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 110 } }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -3
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const d = crow.modelData;
                                if (crow.isPin)
                                    ClipStore.unpin(d.key);
                                else if (ClipStore.isPinned(d.preview))
                                    ClipStore.unpinByPreview(d.preview);
                                else
                                    ClipStore.pin(d.id, d.preview, d.isImage, d.mime);
                            }
                        }
                    }
                }

                MouseArea {
                    id: cma
                    anchors.fill: parent
                    z: -1
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (crow.isPin)
                            ClipStore.copyPin(crow.modelData);
                        else
                            root.copy(crow.modelData.id);
                        pop.close();
                    }
                }
            }
        }
    }
}
