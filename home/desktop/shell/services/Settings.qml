pragma Singleton

// User preferences, persisted to $XDG_STATE_HOME/quickshell/settings.json (state,
// not cache — clearing ~/.cache must not reset your choices). Bind to / assign
// the properties directly; every change is written back automatically.
//
// First run: if settings.json doesn't exist yet, the preferences of the previous
// shell are migrated from ~/.cache/quickshell (accent, background, and the
// notification preferences inside notif-history.json).
//
// Paths are fixed (not Quickshell.stateDir, which is keyed by a hash of the
// config path) so the lock-screen wrapper can find the accent.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")) + "/quickshell"
    readonly property string legacyDir: home + "/.cache/quickshell"

    // ── Appearance ───────────────────────────────────────────────────────────
    property alias accent: adapter.accent // key of palette.json accents
    property alias background: adapter.background // key of palette.json backgrounds

    // ── Notifications (see services/Notifications for semantics) ─────────────
    property alias notifications: adapter.notifications

    // Create the state dir before the first write.
    property bool _dirReady: false
    property bool _savePending: false
    Process {
        running: true
        command: ["mkdir", "-p", root.stateDir]
        onExited: {
            root._dirReady = true;
            if (root._savePending)
                root._save();
        }
    }
    Timer {
        id: saveTimer
        interval: 50
        onTriggered: root._save()
    }
    function _save() {
        if (!_dirReady) {
            _savePending = true;
            return;
        }
        _savePending = false;
        file.writeAdapter();
    }

    FileView {
        id: file
        path: root.stateDir + "/settings.json"
        blockLoading: true
        watchChanges: false
        printErrors: false
        atomicWrites: true
        // Deferred: calling writeAdapter() from inside adapterUpdated makes a
        // second assignment in the same tick get lost (Quickshell 0.3.2).
        onAdapterUpdated: saveTimer.restart()
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                root._migrate();
        }

        JsonAdapter {
            id: adapter
            property string accent: "blue"
            property string background: "medium"
            property JsonObject notifications: JsonObject {
                property var mutedApps: []
                property var silenceRules: [] // [{ id, app, field, op, pattern, mode }]
                property var knownApps: []
                // Per-urgency timeouts: plain = normal, *Crit = critical. Per-app
                // maps hold overrides; an app without one inherits the default.
                property var appTimeouts: ({})
                property int defaultTimeout: 5 // s on screen, -1 = never
                property var appTimeoutsCrit: ({})
                property int defaultTimeoutCrit: -1
                property var appAutoDismiss: ({})
                property int defaultAutoDismiss: 0 // s until cleared from history, 0 = never
                property var appAutoDismissCrit: ({})
                property int defaultAutoDismissCrit: 0
            }
        }
    }

    // ── Migration from the previous shell ────────────────────────────────────
    FileView {
        id: legacyAccent
        path: root.legacyDir + "/accent"
        blockLoading: true
        printErrors: false
    }
    FileView {
        id: legacyBackground
        path: root.legacyDir + "/background"
        blockLoading: true
        printErrors: false
    }
    FileView {
        id: legacyNotif
        path: root.legacyDir + "/notif-history.json"
        blockLoading: true
        printErrors: false
    }

    function _migrate() {
        const acc = (legacyAccent.text() || "").trim();
        if (acc)
            adapter.accent = acc;
        const bg = (legacyBackground.text() || "").trim();
        if (bg)
            adapter.background = bg;
        try {
            const d = JSON.parse(legacyNotif.text() || "{}");
            const n = adapter.notifications;
            for (const k of ["mutedApps", "silenceRules", "knownApps", "appTimeouts", "appTimeoutsCrit", "appAutoDismiss", "appAutoDismissCrit"])
                if (d[k] !== undefined)
                    n[k] = d[k];
            for (const k of ["defaultTimeout", "defaultTimeoutCrit", "defaultAutoDismiss", "defaultAutoDismissCrit"])
                if (typeof d[k] === "number")
                    n[k] = d[k];
        } catch (e) {}
        saveTimer.restart();
    }
}
