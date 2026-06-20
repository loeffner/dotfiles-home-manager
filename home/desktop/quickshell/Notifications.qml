pragma Singleton

// Notification daemon + persistent history.
//
// Model: notifications are *retained* (kept alive, not auto-dismissed) so the
// center can show their actions and let you act on them later — toasts are just
// transient previews (`toastQueue`). `history` is a plain-object log (capped,
// written to disk) that drives the center and survives a qs restart; while a
// notification is still alive we keep a live ref (`_liveById`) so its actions are
// invocable. DND suppresses all toasts; per-app mute suppresses one app's toasts
// while still recording to history.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root

    property bool dnd: false
    readonly property var live: server.trackedNotifications
    property var toastQueue: []           // Notification objects shown as toasts
    property var history: []              // plain [{id,summary,body,appName,appIcon,image,urgency,time}]
    property var mutedApps: []
    property int _nextId: 1
    property var _liveById: ({})          // history id -> live Notification (while alive)

    readonly property string _dir: (Quickshell.env("HOME") || "") + "/.cache/quickshell"

    function isMuted(app) { return mutedApps.indexOf(app || "") >= 0; }
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
            const id = root._nextId++;
            const entry = {
                id: id,
                summary: n.summary ?? "",
                body: n.body ?? "",
                appName: app,
                appIcon: n.appIcon ?? "",
                image: n.image ?? "",
                urgency: n.urgency,
                time: Date.now()
            };

            if (root.dnd || root.isMuted(app)) {
                n.tracked = false; // record to history only, no toast / retention
            } else {
                n.tracked = true;  // retain alive for the center
                root._liveById[id] = n;
                root.toastQueue = [...root.toastQueue, n];
            }

            // Prepend, cap at 50, fully dropping anything evicted.
            const trimmed = [entry, ...root.history];
            for (const e of trimmed.slice(50))
                root._drop(e.id);
            root.history = trimmed.slice(0, 50);
            root._save();
        }
    }

    function removeToast(n) { toastQueue = toastQueue.filter(x => x !== n); }

    // Single dismissal path: dismiss the live notification (if any) and prune it
    // from every place it can linger (toastQueue + _liveById). Callers update
    // `history` separately. Without this, paths other than removeToast/clearAll
    // left stale Notification objects stuck in toastQueue.
    function _drop(id) {
        const n = _liveById[id];
        if (n) {
            n.dismiss();
            toastQueue = toastQueue.filter(x => x !== n);
            delete _liveById[id];
        }
    }

    // The live Notification for a history id, only if still alive (else null).
    function liveFor(id) {
        const n = _liveById[id];
        if (!n)
            return null;
        return (server.trackedNotifications.values || []).indexOf(n) >= 0 ? n : null;
    }
    // Invocable, non-default actions for a history id ([] once the notif is gone).
    function actionsFor(id) {
        const n = liveFor(id);
        return n ? (n.actions || []).filter(a => a.identifier !== "default" && (a.text ?? "") !== "") : [];
    }

    function removeById(id) {
        _drop(id);
        history = history.filter(e => e.id !== id);
        _save();
    }
    function clearApp(app) {
        for (const e of history.filter(e => (e.appName || "") === (app || "")))
            _drop(e.id);
        history = history.filter(e => (e.appName || "") !== (app || ""));
        _save();
    }
    function clearAll() {
        for (const n of (server.trackedNotifications.values || []).slice())
            n.dismiss();
        toastQueue = [];
        _liveById = ({});
        history = [];
        _save();
    }

    function grouped() {
        const map = {}, order = [];
        for (const e of history) {
            const k = e.appName || "";
            if (!(k in map)) { map[k] = []; order.push(k); }
            map[k].push(e);
        }
        return order.map(k => ({ appName: k, items: map[k], count: map[k].length }));
    }

    function iconSource(n) {
        const img = n.image || "";
        if (img && !img.startsWith("image://icon/"))
            return img;
        const ai = n.appIcon || "";
        if (ai) {
            if (ai.startsWith("file://") || ai.startsWith("http") || ai.includes("/"))
                return ai;
            return Quickshell.iconPath(ai, true);
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
