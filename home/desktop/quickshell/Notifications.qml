pragma Singleton

// Notification daemon + persistent history.
//
// `list` is the live tracked set (drives toasts). `history` is a persistent log
// of every notification that arrived — plain JS objects so they survive after a
// notification is dismissed, written to disk so they survive a qs restart. DND
// suppresses all toasts; per-app mute (`mutedApps`) suppresses one app's toasts
// while still recording it to history. Helpers group history by app for the UI.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root

    property bool dnd: false
    readonly property var list: server.trackedNotifications
    // [{ id, summary, body, appName, appIcon, image, urgency, time(ms) }]
    property var history: []
    property var mutedApps: [] // appNames whose toasts are suppressed
    property int _nextId: 1

    readonly property string _dir: (Quickshell.env("HOME") || "") + "/.cache/quickshell"

    function isMuted(app) {
        return mutedApps.indexOf(app || "") >= 0;
    }
    function toggleMute(app) {
        const a = app || "";
        mutedApps = isMuted(a) ? mutedApps.filter(x => x !== a) : [a, ...mutedApps];
        _save();
    }

    NotificationServer {
        id: server
        keepOnReload: false
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        bodyMarkupSupported: true
        onNotification: n => {
            const app = n.appName ?? "";
            // Record to history first (captures the text before any dismiss).
            root.history = [{
                    id: root._nextId++,
                    summary: n.summary ?? "",
                    body: n.body ?? "",
                    appName: app,
                    appIcon: n.appIcon ?? "",
                    image: n.image ?? "",
                    urgency: n.urgency,
                    time: Date.now()
                }, ...root.history].slice(0, 50); // cap at 50 entries
            root._save();
            // Toast unless DND is on or this app is muted.
            n.tracked = !root.dnd && !root.isMuted(app);
        }
    }

    function dismissAll() {
        const items = server.trackedNotifications.values.slice();
        for (const n of items)
            n.dismiss();
    }
    function clearHistory() {
        history = [];
        _save();
    }
    function removeById(id) {
        history = history.filter(e => e.id !== id);
        _save();
    }
    function clearApp(app) {
        history = history.filter(e => (e.appName || "") !== (app || ""));
        _save();
    }

    // Group history by app, preserving most-recent-first order of first sighting.
    function grouped() {
        const map = {}, order = [];
        for (const e of history) {
            const k = e.appName || "";
            if (!(k in map)) {
                map[k] = [];
                order.push(k);
            }
            map[k].push(e);
        }
        return order.map(k => ({ appName: k, items: map[k], count: map[k].length }));
    }

    // Best image/icon source for a notification: prefer a real image (mpris art,
    // screenshot), else resolve the app icon (name -> theme path, or direct path).
    function iconSource(n) {
        const img = n.image || "";
        if (img && !img.startsWith("image://icon/"))
            return img;
        const ai = n.appIcon || "";
        if (ai) {
            if (ai.startsWith("file://") || ai.startsWith("http") || ai.includes("/"))
                return ai;
            return Quickshell.iconPath(ai, true); // "" if not in the icon theme
        }
        if (img.startsWith("image://icon/"))
            return Quickshell.iconPath(img.replace("image://icon/", ""), true);
        return "";
    }

    // ── Persistence ─────────────────────────────────────────────────────────
    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", root._dir]);
        store.reload();
    }

    FileView {
        id: store
        path: root._dir + "/notif-history.json"
        watchChanges: false
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.history = (d.history || []).slice(0, 50);
                root.mutedApps = d.mutedApps || [];
                let mx = 0;
                for (const e of root.history)
                    mx = Math.max(mx, e.id || 0);
                root._nextId = mx + 1;
            } catch (e) {}
        }
    }
    function _save() {
        store.setText(JSON.stringify({ history: history, mutedApps: mutedApps }));
    }
}
