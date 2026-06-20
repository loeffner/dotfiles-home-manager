// On-screen display: a transient pill near the top edge that reacts to volume,
// mute, and media-playback changes — regardless of what caused them (bar scroll,
// a keybind, wpctl/playerctl). It listens to the underlying Pipewire / MPRIS
// state rather than being driven by the keys, so every path that changes volume
// gets feedback. Auto-hides after a short delay.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris

PanelWindow {
    id: osd
    required property var modelData
    screen: modelData

    anchors.top: true
    margins.top: Theme.barHeight + 12
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // Fixed surface size — avoids per-frame Wayland resizes; content centres in it.
    implicitWidth: 260
    implicitHeight: 48
    visible: false

    property string mode: "volume" // "volume" | "mic" | "media"

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property real vol: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property bool micMuted: source?.audio?.muted ?? false

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
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

    function show(m) {
        mode = m;
        visible = true;
        fadeOut.stop();
        fadeIn.start();
        hideTimer.restart();
    }
    function hide() {
        if (!visible)
            return;
        fadeIn.stop();
        fadeOut.start();
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: osd.hide()
    }

    // Audio: react to the default sink / source. onVolumeChanged/onMutedChanged
    // fire only on change (not initial bind), so the OSD doesn't pop at startup.
    Connections {
        target: osd.sink?.audio ?? null
        function onVolumeChanged() { osd.show("volume"); }
        function onMutedChanged() { osd.show("volume"); }
    }
    Connections {
        target: osd.source?.audio ?? null
        function onMutedChanged() { osd.show("mic"); }
    }
    // Media: react to the resolved active player's transport / track changes.
    Connections {
        target: MediaThumb.active
        ignoreUnknownSignals: true
        function onPlaybackStateChanged() { osd.show("media"); }
        function onTrackTitleChanged() { osd.show("media"); }
    }

    Rectangle {
        id: pill
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.bgPopup
        border.width: 1
        border.color: Theme.border
        opacity: 0

        NumberAnimation {
            id: fadeIn
            target: pill; property: "opacity"; to: 1
            duration: 120; easing.type: Easing.OutQuart
        }
        NumberAnimation {
            id: fadeOut
            target: pill; property: "opacity"; to: 0
            duration: 200; easing.type: Easing.InQuart
            onFinished: osd.visible = false
        }

        RowLayout {
            anchors { fill: parent; leftMargin: Theme.pad; rightMargin: Theme.pad }
            spacing: Theme.gap

            Text {
                font.family: Theme.font
                font.pixelSize: Theme.iconSize + 2
                color: Theme.fg
                horizontalAlignment: Text.AlignHCenter
                Layout.preferredWidth: Theme.iconSize + 6
                text: osd.mode === "media"
                      ? (MediaThumb.active && MediaThumb.active.playbackState === MprisPlaybackState.Playing ? "󰏤" : "󰐊")
                      : osd.mode === "mic"
                        ? (osd.micMuted ? "󰍭" : "󰍬")
                        : osd.sinkIcon(osd.vol, osd.muted)
            }

            // Volume mode: slider bar + percentage.
            Rectangle {
                visible: osd.mode === "volume"
                Layout.fillWidth: true
                implicitHeight: 6
                radius: 3
                color: Theme.bg1
                Rectangle {
                    width: parent.width * Math.min(1, osd.vol)
                    height: parent.height
                    radius: 3
                    color: osd.muted ? Theme.dim : Theme.accent
                    Behavior on width { NumberAnimation { duration: 80 } }
                }
            }
            Text {
                visible: osd.mode === "volume"
                text: Math.round(osd.vol * 100) + "%"
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                Layout.minimumWidth: 34
                horizontalAlignment: Text.AlignRight
            }

            // Mic / media mode: a single label instead of the bar.
            Text {
                visible: osd.mode !== "volume"
                Layout.fillWidth: true
                elide: Text.ElideRight
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                text: osd.mode === "mic"
                      ? (osd.micMuted ? "Microphone muted" : "Microphone on")
                      : (MediaThumb.active ? (MediaThumb.active.trackTitle || "") : "")
            }
        }
    }
}
