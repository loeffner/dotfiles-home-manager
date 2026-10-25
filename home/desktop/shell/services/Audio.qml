pragma Singleton

// Pipewire audio: default output (sink) / input (source) volume + mute, the
// device lists for the pickers, and helpers to name / iconify a device.
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property bool micMuted: source?.audio?.muted ?? false
    // -1 until the default sink is known (lets watchers skip the initial value).
    readonly property real monitoredVolume: sink?.audio?.volume ?? -1

    readonly property var outputs: (Pipewire.nodes?.values ?? []).filter(n => n && n.audio && n.isSink && !n.isStream)
    readonly property var inputs: (Pipewire.nodes?.values ?? []).filter(n => n && n.audio && !n.isSink && !n.isStream)

    // Track the defaults, and every node so non-default devices' audio metadata
    // (needed by the filters above) is populated.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }
    PwObjectTracker {
        objects: Pipewire.nodes ? Pipewire.nodes.values : []
    }

    function setVolume(v) {
        if (sink?.audio)
            sink.audio.volume = Math.max(0, Math.min(1, v));
    }
    function setMicVolume(v) {
        if (source?.audio)
            source.audio.volume = Math.max(0, Math.min(1, v));
    }
    function toggleMute() {
        if (sink?.audio)
            sink.audio.muted = !sink.audio.muted;
    }
    function toggleMicMute() {
        if (source?.audio)
            source.audio.muted = !source.audio.muted;
    }
    function setDefaultOutput(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }
    function setDefaultInput(node) {
        Pipewire.preferredDefaultAudioSource = node;
    }

    function volumeIcon(v, m) {
        return m || v <= 0 ? "volume_off" : v < 0.34 ? "volume_mute" : v < 0.67 ? "volume_down" : "volume_up";
    }
    function deviceName(n) {
        return n ? (n.description || n.nickname || n.name || "Unknown") : "";
    }
    // A fitting Material Symbol for a device, inferred from its name.
    function deviceIcon(n, isOutput) {
        const s = deviceName(n).toLowerCase();
        if (s.includes("webcam") || s.includes("camera"))
            return "videocam";
        if (s.includes("head") || s.includes("earbud") || s.includes("airpod"))
            return "headphones";
        if (s.includes("hdmi") || s.includes("display") || s.includes("tv"))
            return "tv";
        if (s.includes("soundbar") || s.includes("speaker"))
            return "speaker";
        if (!isOutput && (s.includes("mic") || s.includes("blue")))
            return "mic";
        return isOutput ? "speaker" : "mic";
    }
}
