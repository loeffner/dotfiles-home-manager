// Now-playing widget (MPRIS): just a play/pause glyph shown next to the centre
// clock while a player exists. The glyph toggles playback directly.
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Item {
    id: root

    readonly property var player: MediaThumb.active
    readonly property bool playing: player && player.playbackState === MprisPlaybackState.Playing

    visible: player !== null
    implicitWidth: visible ? 20 : 0
    implicitHeight: Theme.barHeight

    MIcon {
        anchors.centerIn: parent
        text: root.playing ? "pause" : "play_arrow"
        size: 20
        color: playMa.containsMouse ? Theme.iconHover : Theme.surfaceText
        scale: playMa.containsMouse ? 1.15 : 1.0
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }
    MouseArea {
        id: playMa
        anchors.fill: parent
        anchors.margins: -3
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.player?.togglePlaying()
    }
}
