// Audio widget: icon + percentage in the bar. Scroll to adjust, right-click to
// mute, left-click opens a slider popup (output volume + a mic mute toggle).
// PwObjectTracker is required — without binding the nodes, their volume/mute
// data is never populated.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

Item {
    id: root
    required property var bar

    implicitWidth: row.implicitWidth
    implicitHeight: Theme.barHeight

    opacity: ma.containsMouse ? 1.0 : 0.82
    Behavior on opacity {
        NumberAnimation {
            duration: 70
        }
    }

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real vol: sink?.audio?.volume ?? 0
    readonly property bool micMuted: source?.audio?.muted ?? false

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    function setVol(v) {
        if (sink?.audio)
            sink.audio.volume = Math.max(0, Math.min(1, v));
    }
    function sinkIcon(v, m) {
        if (m || v <= 0)
            return "󰝟";
        if (v < 0.34)
            return "󰕿";
        if (v < 0.67)
            return "󰖀";
        return "󰕾";
    }

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: Theme.gap

        // Fixed widths so the cluster doesn't shuffle as the glyph/percent change.
        Text {
            text: root.sinkIcon(root.vol, root.muted)
            font.family: Theme.font
            font.pixelSize: Theme.iconSize
            color: root.muted ? Theme.dim : Theme.fg
            horizontalAlignment: Text.AlignHCenter
            Layout.preferredWidth: Theme.iconSize + 4
        }
        Text {
            text: Math.round(root.vol * 100) + "%"
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            color: root.muted ? Theme.dim : Theme.fg
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: 32
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: e => {
            if (e.button === Qt.RightButton) {
                if (root.sink?.audio)
                    root.sink.audio.muted = !root.sink.audio.muted;
            } else {
                popup.toggle();
            }
        }
        onWheel: w => {
            root.setVol(root.vol + (w.angleDelta.y > 0 ? 0.05 : -0.05));
        }
    }

    BarPopup {
        id: popup
        bar: root.bar
        anchorItem: root
        popWidth: 280

        Text {
            text: "Output volume"
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gap

            Text {
                text: root.sinkIcon(root.vol, root.muted)
                color: root.muted ? Theme.dim : Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.iconSize

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.sink?.audio)
                        root.sink.audio.muted = !root.sink.audio.muted
                }
            }

            // Custom slider — a track with an accent fill, dragged/clicked to set.
            Rectangle {
                id: track
                Layout.fillWidth: true
                implicitHeight: 6
                radius: 3
                color: Theme.bg1

                Rectangle {
                    width: parent.width * root.vol
                    height: parent.height
                    radius: 3
                    color: root.muted ? Theme.dim : Theme.accent
                }

                MouseArea {
                    anchors.fill: parent
                    onPressed: e => root.setVol(e.x / width)
                    onPositionChanged: e => root.setVol(e.x / width)
                }
            }

            Text {
                text: Math.round(root.vol * 100) + "%"
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                Layout.minimumWidth: 34
                horizontalAlignment: Text.AlignRight
            }
        }

        // Microphone mute toggle. Wrapped in a plain Item so the row-spanning
        // MouseArea anchors freely without fighting the parent layout.
        Item {
            Layout.fillWidth: true
            implicitHeight: micRow.implicitHeight

            RowLayout {
                id: micRow
                anchors.fill: parent
                spacing: Theme.gap

                Text {
                    text: root.micMuted ? "󰍭" : "󰍬"
                    color: root.micMuted ? Theme.dim : Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.iconSize
                }
                Text {
                    text: root.micMuted ? "Microphone muted" : "Microphone on"
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    Layout.fillWidth: true
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.source?.audio)
                    root.source.audio.muted = !root.source.audio.muted
            }
        }
    }
}
