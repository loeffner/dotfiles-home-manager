pragma Singleton

// Sound effects for the shell (notifications, and later volume/power). Plays
// freedesktop sound-theme *events* by name via canberra-gtk-play — so no file
// paths and no QtMultimedia dependency; canberra resolves the actual audio from
// the installed sound-theme-freedesktop against XDG_DATA_DIRS.
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root
    property bool enabled: true

    // event ids from the freedesktop sound theme
    property string normalEvent: "message-new-instant"
    property string criticalEvent: "dialog-warning"

    function play(event) {
        if (!enabled || !event)
            return;
        Quickshell.execDetached(["canberra-gtk-play", "-i", event]);
    }
    function notify(critical) {
        play(critical ? criticalEvent : normalEvent);
    }

    // Global volume feedback: a soft blip at the new level whenever the default
    // sink's volume changes — slider, media keys, or wpctl. Debounced so a drag
    // yields one blip, and primed so it stays quiet on startup.
    property bool volumeFeedback: true
    readonly property PwNode _sink: Pipewire.defaultAudioSink
    // Reactive volume: re-evaluates whenever the sink or its volume changes, so
    // the change handler fires reliably (a Connections target on the audio object
    // silently missed changes when the object was swapped).
    readonly property real monitoredVolume: _sink?.audio?.volume ?? -1
    property bool _primed: false
    property double _lastBlip: 0
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }
    onMonitoredVolumeChanged: {
        if (monitoredVolume < 0)
            return;
        if (!_primed) {
            _primed = true;
            return;
        }
        if (!volumeFeedback)
            return;
        // Throttle so a held media key / drag gives steady feedback, not one blip.
        const now = Date.now();
        if (now - _lastBlip < 70)
            return;
        _lastBlip = now;
        play("audio-volume-change");
    }
}
