pragma Singleton

// Single source of truth for "the media player we control" and its cover art.
//
// Active-player selection is *held*, not recomputed on every binding read: a
// plain reactive expression flapped between a browser's two MPRIS players (one
// carrying art, one not), which made the cover art flicker. We instead resolve
// `active` only on meaningful signals and never select an idle player.
//
// Cover art resolves via trackArtUrl -> mpris:artUrl -> a YouTube thumbnail
// derived from the *stable* xesam:url (img.youtube.com/vi/<id>/...). Remote art
// is cached on disk keyed by a content hash, so the same track reuses one file
// (no re-download, survives restarts) instead of churning timestamped temps.
//
// Pattern adapted from DankMaterialShell's MprisController + TrackArtService.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: root

    // ── Active player ───────────────────────────────────────────────────────
    readonly property list<MprisPlayer> players: Mpris.players.values
    property MprisPlayer active: null

    function isIdle(p) {
        return p
            && p.playbackState === MprisPlaybackState.Stopped
            && !p.trackTitle
            && !p.trackArtist;
    }

    // Firefox spawns a throwaway MPRIS player for YouTube hover-previews; ignore it.
    function isFirefoxYoutubeHoverPreview(p) {
        if (!p)
            return false;
        const id = (p.identity || "").toLowerCase();
        if (!id.includes("firefox"))
            return false;
        const url = (p.metadata?.["xesam:url"] || "").toString();
        return /^https?:\/\/(www\.)?youtube\.com\/?($|\?|#)/i.test(url);
    }

    function _resolve() {
        // Prefer an actually-playing, non-phantom player.
        const playing = players.find(p => p.isPlaying && !isFirefoxYoutubeHoverPreview(p))
            ?? players.find(p => p.isPlaying);
        if (playing) {
            active = playing;
            return;
        }
        // Otherwise keep the current player while it's still valid.
        if (active && players.indexOf(active) >= 0 && !isIdle(active))
            return;
        // Else fall back to the first controllable, non-idle player.
        active = players.find(p => p.canControl && !isIdle(p)) ?? null;
    }

    onPlayersChanged: _resolve()
    Component.onCompleted: _resolve()

    // Re-resolve when any player starts playing.
    Instantiator {
        model: root.players
        delegate: Connections {
            required property MprisPlayer modelData
            target: modelData
            function onIsPlayingChanged() {
                if (modelData.isPlaying)
                    root._resolve();
            }
        }
    }

    // Track the active player: re-resolve if it goes idle, refresh art on changes.
    Connections {
        target: root.active
        ignoreUnknownSignals: true
        function onTrackTitleChanged() {
            if (root.isIdle(root.active))
                root._resolve();
            root._updateArt();
        }
        function onTrackArtistChanged() {
            if (root.isIdle(root.active))
                root._resolve();
        }
        function onPlaybackStateChanged() {
            if (root.isIdle(root.active))
                root._resolve();
        }
        function onTrackArtUrlChanged() { root._updateArt(); }
        function onMetadataChanged() { root._updateArt(); }
    }

    // Rewind to start if we're well into the track, else go to the previous one.
    function previousOrRewind() {
        if (!active)
            return;
        if (active.position > 8 && active.canSeek)
            active.position = 0.1;
        else if (active.canGoPrevious)
            active.previous();
    }

    // ── Cover art ───────────────────────────────────────────────────────────
    property string path: ""   // local file:// URL for Image { source: ... }
    property bool loading: false
    property string _lastArtUrl: ""

    function _djb2(str) {
        if (!str)
            return "";
        let h = 5381;
        for (let i = 0; i < str.length; i++) {
            h = ((h << 5) + h) + str.charCodeAt(i);
            h = h & 0x7FFFFFFF;
        }
        return h.toString(16).padStart(8, '0');
    }

    function _artworkUrl(p) {
        if (!p)
            return "";
        let a = p.trackArtUrl || "";
        if (a !== "")
            return a;
        if (p.metadata && p.metadata["mpris:artUrl"]) {
            a = p.metadata["mpris:artUrl"].toString();
            if (a !== "")
                return a;
        }
        // YouTube: derive a thumbnail from the stable page URL.
        if (p.metadata && p.metadata["xesam:url"]) {
            const url = p.metadata["xesam:url"].toString();
            if (url.includes("youtube.com") || url.includes("youtu.be")) {
                const re = /^.*(youtu.be\/|v\/|u\/\w\/|embed\/|watch\?v=|\&v=)([^#\&\?]*).*/;
                const m = url.match(re);
                if (m && m[2].length === 11)
                    return "https://img.youtube.com/vi/" + m[2] + "/hqdefault.jpg";
            }
        }
        return "";
    }

    onActiveChanged: _updateArt()
    function _updateArt() { _loadArt(_artworkUrl(active)); }

    function _loadArt(url) {
        if (!url) {
            path = "";
            _lastArtUrl = "";
            loading = false;
            return;
        }
        if (url === _lastArtUrl)
            return;
        _lastArtUrl = url;

        if (url.startsWith("http://") || url.startsWith("https://")) {
            loading = true;
            const hash = _djb2(url);
            const dir = (Quickshell.env("HOME") || "") + "/.cache/quickshell/media";
            const file = dir + "/remote_" + hash;

            // For YouTube fall through quality tiers; otherwise just the one URL.
            let urls = [url];
            if (url.includes("img.youtube.com/vi/")) {
                const vid = url.split("/vi/")[1].split("/")[0];
                urls = ["https://img.youtube.com/vi/" + vid + "/maxresdefault.jpg",
                        "https://img.youtube.com/vi/" + vid + "/hqdefault.jpg",
                        "https://img.youtube.com/vi/" + vid + "/mqdefault.jpg"];
            }

            // mkdir, reuse cache if present, else try each URL into a temp + mv.
            fetcher.target = url;
            fetcher.file = file;
            fetcher.command = ["sh", "-c",
                'mkdir -p "$1"; out="$2"; shift 2; '
                + 'if [ -f "$out" ]; then exit 0; fi; '
                + 'for u in "$@"; do if curl -fsL --max-time 15 -o "$out.tmp" "$u"; then mv "$out.tmp" "$out"; exit 0; fi; done; '
                + 'rm -f "$out.tmp"; exit 1',
                "sh", dir, file].concat(urls);
            fetcher.running = false;
            fetcher.running = true;
        } else {
            loading = false;
            path = url.startsWith("file://") ? url : "file://" + url;
        }
    }

    Process {
        id: fetcher
        property string target: ""
        property string file: ""
        onExited: code => {
            root.loading = false;
            if (root._lastArtUrl !== target)
                return; // a newer request superseded this one
            root.path = code === 0 ? "file://" + file : "";
        }
    }
}
