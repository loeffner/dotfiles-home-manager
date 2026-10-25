// Play/pause glyph beside the clock while a media player exists.
import QtQuick
import Quickshell.Services.Mpris
import qs.config
import qs.components
import qs.services

BarIcon {
    readonly property bool playing: Player.active?.playbackState === MprisPlaybackState.Playing
    visible: Player.active !== null
    icon: playing ? "pause" : "play_arrow"
    onClicked: Player.active?.togglePlaying()
}
