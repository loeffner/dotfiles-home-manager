pragma Singleton

// Notification daemon + history.
//
// Notifications are *retained* (kept alive, not auto-dismissed) so the center can
// still invoke their actions later; toasts are just transient previews
// (`toasts`). `history` is a plain-object log (capped at 50, persisted) that
// drives the center and survives restarts; while a notification is alive its
// live object is kept in a private map and its id listed in `liveIds` (reactive,
// so counts and action buttons update when apps close notifications).
//
// Entry shape: { id, summary, body, appName, desktopEntry, appIcon, image,
//                urgency, time }
//
// Silencing (preferences in Settings.notifications):
//   • DND (session only) and per-app mute suppress toasts + sound, still log.
//   • Rules match an entry's title / body / app:
//       { id, app, field: title|body|any|app, op: contains|not_contains|equals|regex,
//         pattern, mode: mute|block }   — block discards entirely.
//   • Per-app, per-urgency timeouts: on-screen time (-1 = never) and
//     auto-dismiss from history (0 = never); apps inherit the defaults.
//
// First run migrates the previous shell's history from
// ~/.cache/quickshell/notif-history.json.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

Singleton {
    id: root

    property bool dnd: false
    readonly property var prefs: Settings.notifications
    readonly property alias history: store.history
    property var toasts: [] // entries currently shown as toasts
    property var liveIds: [] // ids whose notification is still alive
    readonly property int activeCount: liveIds.length
    property var _live: ({}) // id -> live Notification

    // ── Queries ──────────────────────────────────────────────────────────────
    function isLive(id) {
        return liveIds.indexOf(id) >= 0;
    }
    function liveFor(id) {
        return isLive(id) ? (_live[id] ?? null) : null;
    }
    // Invocable, non-default actions for an entry ([] once it's gone).
    function actionsFor(id) {
        const n = liveFor(id);
        return n ? (n.actions || []).filter(a => a.identifier !== "default" && (a.text ?? "") !== "") : [];
    }
    function invokeDefault(id) {
        const n = liveFor(id);
        for (const a of (n && n.actions) || [])
            if (a.identifier === "default") {
                a.invoke();
                return true;
            }
        return false;
    }
    function isCritical(entry) {
        return entry.urgency === NotificationUrgency.Critical;
    }
    // Group entries by app, keeping recency order.
    function groupByApp(entries) {
        const map = {}, order = [];
        for (const e of entries) {
            const k = e.appName || "";
            if (!(k in map)) {
                map[k] = [];
                order.push(k);
            }
            map[k].push(e);
        }
        return order.map(k => ({
                    "appName": k,
                    "items": map[k],
                    "count": map[k].length
                }));
    }
    function iconSource(entry) {
        const img = entry.image || "";
        if (img && !img.startsWith("image://icon/"))
            return img;
        const ai = entry.appIcon || "";
        if (ai)
            return (ai.startsWith("file://") || ai.startsWith("http") || ai.includes("/")) ? ai : Quickshell.iconPath(ai, true);
        if (img.startsWith("image://icon/"))
            return Quickshell.iconPath(img.replace("image://icon/", ""), true);
        return "";
    }

    // ── Dismissal ────────────────────────────────────────────────────────────
    function dismissToast(id) {
        toasts = toasts.filter(e => e.id !== id);
    }
    function remove(id) {
        _drop(id);
        store.history = store.history.filter(e => e.id !== id);
    }
    function clearApp(app) {
        for (const e of store.history.filter(e => (e.appName || "") === (app || "")))
            _drop(e.id);
        store.history = store.history.filter(e => (e.appName || "") !== (app || ""));
    }
    function clearAll() {
        for (const n of (server.trackedNotifications.values || []).slice())
            n.dismiss();
        toasts = [];
        _live = {};
        liveIds = [];
        store.history = [];
    }
    // Dismiss the live notification (if any) and prune it from toasts + live set.
    function _drop(id) {
        const n = _live[id];
        if (n)
            n.dismiss(); // its closed handler prunes the live set too
        toasts = toasts.filter(e => e.id !== id);
        _forget(id);
    }
    function _forget(id) {
        delete _live[id];
        if (isLive(id))
            liveIds = liveIds.filter(x => x !== id);
    }

    // ── Muting + rules ───────────────────────────────────────────────────────
    function isMuted(app) {
        return prefs.mutedApps.indexOf(app || "") >= 0;
    }
    function toggleMute(app) {
        const a = app || "";
        prefs.mutedApps = isMuted(a) ? prefs.mutedApps.filter(x => x !== a) : [a, ...prefs.mutedApps];
    }
    function unmute(app) {
        prefs.mutedApps = prefs.mutedApps.filter(x => x !== (app || ""));
    }
    function clearAllMutes() {
        prefs.mutedApps = [];
    }

    // One operator on one text; regex is case-insensitive and an invalid pattern
    // never matches.
    function _textMatch(text, op, pat) {
        const t = text || "";
        if (op === "regex") {
            try {
                return new RegExp(pat, "i").test(t);
            } catch (e) {
                return false;
            }
        }
        const tl = t.toLowerCase(), pl = (pat || "").toLowerCase();
        if (op === "equals")
            return tl === pl;
        if (op === "not_contains")
            return tl.indexOf(pl) < 0;
        return tl.indexOf(pl) >= 0;
    }
    function _ruleMatch(entry, r) {
        if (r.app && (entry.appName || "") !== r.app)
            return false;
        if (r.field === "app")
            return !!r.app;
        const op = r.op || "contains", pat = r.pattern || "";
        if (!pat)
            return false;
        const s = entry.summary || "", b = entry.body || "";
        if (r.field === "body")
            return _textMatch(b, op, pat);
        if (r.field === "any") // "does not contain" must hold for both fields
            return op === "not_contains" ? (_textMatch(s, op, pat) && _textMatch(b, op, pat)) : (_textMatch(s, op, pat) || _textMatch(b, op, pat));
        return _textMatch(s, op, pat);
    }
    // Strongest matching mode: "block" beats "mute"; "" = none.
    function silenceMode(entry) {
        let mode = "";
        for (const r of prefs.silenceRules)
            if (_ruleMatch(entry, r)) {
                if ((r.mode || "mute") === "block")
                    return "block";
                mode = "mute";
            }
        return mode;
    }
    function addRule(app, field, pattern, mode, op) {
        const f = field || "title", pat = (pattern || "").trim();
        if (f !== "app" && !pat)
            return;
        const a = app || "", m = mode === "block" ? "block" : "mute", o = op || "contains";
        const rules = prefs.silenceRules;
        if (rules.some(r => (r.app || "") === a && (r.field || "title") === f && (r.op || "contains") === o && (r.pattern || "") === pat && (r.mode || "mute") === m))
            return;
        const nextId = Math.max(0, ...rules.map(r => r.id || 0)) + 1;
        prefs.silenceRules = [{ "id": nextId, "app": a, "field": f, "op": o, "pattern": pat, "mode": m }, ...rules];
    }
    function removeRule(id) {
        prefs.silenceRules = prefs.silenceRules.filter(r => r.id !== id);
    }
    function clearRules() {
        prefs.silenceRules = [];
    }

    // ── Timeouts (all take `crit` to pick the urgency track) ─────────────────
    function _override(map, app) {
        const v = map[app || ""];
        return (v === undefined || v === null) ? undefined : v;
    }
    function _setOverride(name, app, secs) {
        const m = Object.assign({}, prefs[name]);
        if (secs === undefined)
            delete m[app || ""];
        else
            m[app || ""] = secs;
        prefs[name] = m;
    }
    // On-screen toast time in seconds; -1 = never auto-dismiss.
    function timeoutOverride(app, crit) {
        return _override(crit ? prefs.appTimeoutsCrit : prefs.appTimeouts, app);
    }
    function timeoutFor(app, crit) {
        return timeoutOverride(app, crit) ?? (crit ? prefs.defaultTimeoutCrit : prefs.defaultTimeout);
    }
    function setAppTimeout(app, secs, crit) {
        _setOverride(crit ? "appTimeoutsCrit" : "appTimeouts", app, secs);
    }
    function setDefaultTimeout(secs, crit) {
        if (crit)
            prefs.defaultTimeoutCrit = secs;
        else
            prefs.defaultTimeout = secs;
    }
    // Auto-dismiss age in seconds; 0 = off.
    function autoDismissOverride(app, crit) {
        return _override(crit ? prefs.appAutoDismissCrit : prefs.appAutoDismiss, app);
    }
    function autoDismissFor(app, crit) {
        return autoDismissOverride(app, crit) ?? (crit ? prefs.defaultAutoDismissCrit : prefs.defaultAutoDismiss);
    }
    function setAppAutoDismiss(app, secs, crit) {
        _setOverride(crit ? "appAutoDismissCrit" : "appAutoDismiss", app, secs);
        pruneOld();
    }
    function setDefaultAutoDismiss(secs, crit) {
        if (crit)
            prefs.defaultAutoDismissCrit = secs;
        else
            prefs.defaultAutoDismiss = secs;
        pruneOld();
    }

    // Drop entries older than their app's auto-dismiss age.
    function pruneOld() {
        const now = Date.now();
        const old = store.history.filter(e => {
            const ad = autoDismissFor(e.appName, isCritical(e));
            return ad > 0 && e.time < now - ad * 1000;
        });
        if (old.length === 0)
            return;
        for (const e of old)
            _drop(e.id);
        const gone = new Set(old.map(e => e.id));
        store.history = store.history.filter(e => !gone.has(e.id));
    }
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.pruneOld()
    }

    // ── Server ───────────────────────────────────────────────────────────────
    function _entry(n, id) {
        return {
            "id": id,
            "summary": n.summary ?? "",
            "body": n.body ?? "",
            "appName": n.appName ?? "",
            "desktopEntry": n.desktopEntry ?? "",
            "appIcon": n.appIcon ?? "",
            "image": n.image ?? "",
            "urgency": n.urgency,
            "time": Date.now()
        };
    }
    function _surfaces(entry) {
        return !dnd && !isMuted(entry.appName) && silenceMode(entry) !== "mute";
    }
    function _sound(n) {
        if (!(n.hints && n.hints["suppress-sound"])) // e.g. players with their own audio
            Sound.notify(n.urgency === NotificationUrgency.Critical);
    }
    function _record(entry) {
        const all = [entry, ...store.history];
        for (const e of all.slice(50))
            _drop(e.id);
        store.history = all.slice(0, 50);
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
            if (app && root.prefs.knownApps.indexOf(app) < 0)
                root.prefs.knownApps = [...root.prefs.knownApps, app];
            const id = store.nextId;
            store.nextId = id + 1;
            const entry = root._entry(n, id);

            if (root.silenceMode(entry) === "block") {
                n.tracked = false;
                return;
            }
            if (!root._surfaces(entry)) {
                n.tracked = false; // history only, no toast / retention
                root._record(entry);
                return;
            }

            n.tracked = true;
            root._live[id] = n;
            root.liveIds = [...root.liveIds, id];
            root.toasts = [...root.toasts, entry];
            root._sound(n);

            // quickshell destroys the Notification right after `closed`
            // (expiry / dismissal / CloseNotification), so prune every live ref
            // here; the toast removal is deferred past the destruction.
            n.closed.connect(() => {
                root._forget(id);
                Qt.callLater(() => root.dismissToast(id));
            });
            // In-place updates (replaces_id, e.g. Discord's "3 new messages")
            // reuse the object without re-emitting `notification`; callLater
            // collapses the burst of change signals into one refresh.
            const refresh = () => Qt.callLater(() => root._refresh(id));
            n.summaryChanged.connect(refresh);
            n.bodyChanged.connect(refresh);
            n.imageChanged.connect(refresh);
            n.urgencyChanged.connect(refresh);
            n.actionsChanged.connect(refresh);
            n.hintsChanged.connect(refresh);

            root._record(entry);
        }
    }

    // Re-sync after an in-place update: the update is effectively the newest
    // notification — move it to the front, re-apply rules, resurface the toast
    // (a fresh entry object restarts its timer) and replay the sound.
    function _refresh(id) {
        const n = _live[id];
        if (!n)
            return;
        const entry = _entry(n, id);
        if (silenceMode(entry) === "block") {
            // Untracking destroys n without `closed`, so clean up explicitly.
            _forget(id);
            toasts = toasts.filter(e => e.id !== id);
            store.history = store.history.filter(e => e.id !== id);
            n.tracked = false;
            return;
        }
        store.history = [entry, ...store.history.filter(e => e.id !== id)].slice(0, 50);
        if (!_surfaces(entry)) {
            toasts = toasts.filter(e => e.id !== id);
            return;
        }
        toasts = toasts.some(e => e.id === id) ? toasts.map(e => e.id === id ? entry : e) : [...toasts, entry];
        _sound(n);
    }

    // ── Persistence + migration ──────────────────────────────────────────────
    property bool _dirReady: false
    property bool _dirty: false
    Timer {
        id: saveTimer
        interval: 50
        onTriggered: {
            if (root._dirReady)
                file.writeAdapter();
            else
                root._dirty = true;
        }
    }
    Process {
        running: true
        command: ["mkdir", "-p", Settings.stateDir]
        onExited: {
            root._dirReady = true;
            if (root._dirty)
                file.writeAdapter();
        }
    }
    FileView {
        id: file
        path: Settings.stateDir + "/notifications.json"
        blockLoading: true
        watchChanges: false
        printErrors: false
        atomicWrites: true
        // Deferred: calling writeAdapter() from inside adapterUpdated makes a
        // second assignment in the same tick get lost (Quickshell 0.3.2).
        onAdapterUpdated: saveTimer.restart()
        onLoaded: root.pruneOld()
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                root._migrate();
        }
        JsonAdapter {
            id: store
            property var history: []
            property int nextId: 1
        }
    }
    FileView {
        id: legacy
        path: Settings.legacyDir + "/notif-history.json"
        blockLoading: true
        printErrors: false
    }
    function _migrate() {
        try {
            const h = (JSON.parse(legacy.text() || "{}").history || []).slice(0, 50);
            if (h.length > 0) {
                store.history = h;
                store.nextId = Math.max(0, ...h.map(e => e.id || 0)) + 1;
            }
        } catch (e) {}
        pruneOld();
    }
}
