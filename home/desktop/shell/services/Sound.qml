pragma Singleton

// Sound effects: freedesktop sound-theme events played by name via
// canberra-gtk-play (no file paths, no QtMultimedia). Plays the notification
// sounds, and a debounced blip on every default-sink volume change (slider,
// media keys or wpctl) — primed so startup stays quiet.
import QtQuick
import Quickshell

Singleton {
    id: root
    property bool enabled: true
    property bool volumeFeedback: true

    readonly property string normalEvent: "message-new-instant"
    readonly property string criticalEvent: "dialog-warning"

    function play(event) {
        if (enabled && event)
            Quickshell.execDetached(["canberra-gtk-play", "-i", event]);
    }
    function notify(critical) {
        play(critical ? criticalEvent : normalEvent);
    }

    property bool _primed: false
    property double _lastBlip: 0
    Connections {
        target: Audio
        function onMonitoredVolumeChanged() {
            if (Audio.monitoredVolume < 0)
                return;
            if (!root._primed) {
                root._primed = true;
                return;
            }
            if (!root.volumeFeedback)
                return;
            // Throttle so a held key / drag gives steady feedback, not a blip storm.
            const now = Date.now();
            if (now - root._lastBlip < 70)
                return;
            root._lastBlip = now;
            root.play("audio-volume-change");
        }
    }
}
