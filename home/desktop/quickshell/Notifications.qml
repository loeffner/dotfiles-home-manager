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
    property var toastQueue: []           // plain entries (same shape as history) shown as toasts
    property var history: []              // plain [{id,summary,body,appName,appIcon,image,urgency,time}]
    property var mutedApps: []
    // Fine-grained silencing: rules matching a notification's title/body substring
    // — narrower than muting a whole app (many things share an app, e.g. Firefox).
    // Each rule:
    //   { id, app, field, op, pattern, mode }
    //     app     — app name to scope to, or "" = any app
    //     field   — "title" | "body" | "any" (which text to match) | "app" (all of it)
    //     op      — "contains" | "not_contains" | "equals" | "regex"  (unused for "app")
    //     pattern — the needle (substring / exact text / regex source); "" for "app"
    //     mode    — "mute"  = suppress toast + sound, still log to history
    //             — "block" = discard entirely (no toast, no sound, no history)
    property var silenceRules: []
    property int _nextRuleId: 1
    property int _nextId: 1
    property var _liveById: ({})          // history id -> live Notification (while alive)

    // Settings (persisted). knownApps accrue as apps first notify, so the
    // settings UI can list them. Two independent per-app timeouts, each with a
    // global default an app inherits unless it has an override (unset in the map):
    //   • on-screen toast time  — appTimeouts / defaultTimeout   (-1 = never)
    //   • auto-dismiss from history — appAutoDismiss / defaultAutoDismiss (0 = off)
    // Auto-dismiss keeps a session from piling up (e.g. across many rebuilds).
    property var knownApps: []
    // Timeouts are split by urgency: the "…Crit" variants apply to Critical
    // notifications, the plain ones to normal. Defaults keep Critical on screen
    // and in history until dismissed.
    property var appTimeouts: ({})
    property int defaultTimeout: 5
    property var appTimeoutsCrit: ({})
    property int defaultTimeoutCrit: -1
    property var appAutoDismiss: ({})
    property int defaultAutoDismiss: 0
    property var appAutoDismissCrit: ({})
    property int defaultAutoDismissCrit: 0

    readonly property string _dir: (Quickshell.env("HOME") || "") + "/.cache/quickshell"

    function isMuted(app) { return mutedApps.indexOf(app || "") >= 0; }
    function toggleMute(app) {
        const a = app || "";
        mutedApps = isMuted(a) ? mutedApps.filter(x => x !== a) : [a, ...mutedApps];
        _save();
    }
    function unmute(app) { mutedApps = mutedApps.filter(x => x !== (app || "")); _save(); }
    function clearAllMutes() { mutedApps = []; _save(); }

    // Apply one operator to one text field. Regex is case-insensitive and guarded
    // (an invalid pattern simply never matches).
    function _txtMatch(text, op, pat) {
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
        return tl.indexOf(pl) >= 0; // "contains" (default)
    }
    // Does a history entry match a single silence rule?
    function _silenceMatch(entry, r) {
        if (r.app && (entry.appName || "") !== r.app)
            return false;
        if (r.field === "app")
            return !!r.app; // whole-app rule (matches everything from that app)
        const op = r.op || "contains";
        const pat = r.pattern || "";
        if (!pat)
            return false;
        const s = entry.summary || "", b = entry.body || "";
        if (r.field === "body")
            return _txtMatch(b, op, pat);
        if (r.field === "any")
            // "does not contain" must hold for BOTH fields; the rest match either.
            return op === "not_contains" ? (_txtMatch(s, op, pat) && _txtMatch(b, op, pat)) : (_txtMatch(s, op, pat) || _txtMatch(b, op, pat));
        return _txtMatch(s, op, pat); // "title" (default)
    }
    // Strongest silence mode for an entry: "block" wins over "mute", "" = none.
    function silenceMode(entry) {
        let mode = "";
        for (const r of silenceRules) {
            if (_silenceMatch(entry, r)) {
                if ((r.mode || "mute") === "block")
                    return "block";
                mode = "mute";
            }
        }
        return mode;
    }
    // Create a rule (usually from a notification the user clicked "silence" on, so
    // the pattern is captured verbatim — no typing). De-dupes identical rules.
    function addSilenceRule(app, field, pattern, mode, op) {
        const f = field || "title";
        const pat = (pattern || "").trim();
        if (f !== "app" && !pat)
            return;
        const a = app || "", m = (mode === "block") ? "block" : "mute", o = op || "contains";
        if (silenceRules.some(r => (r.app || "") === a && (r.field || "title") === f && (r.op || "contains") === o && (r.pattern || "") === pat && (r.mode || "mute") === m))
            return;
        silenceRules = [{ "id": _nextRuleId++, "app": a, "field": f, "op": o, "pattern": pat, "mode": m }, ...silenceRules];
        _save();
    }
    function removeSilenceRule(id) { silenceRules = silenceRules.filter(r => r.id !== id); _save(); }
    function clearSilenceRules() { silenceRules = []; _save(); }

    // Generic per-app setting helpers: pass secs === undefined to clear the
    // override (the app falls back to the global default).
    function _setOverride(mapName, app, secs) {
        const m = Object.assign({}, root[mapName]);
        if (secs === undefined)
            delete m[app || ""];
        else
            m[app || ""] = secs;
        root[mapName] = m;
        _save();
    }

    // All timeout getters/setters take a `crit` bool selecting the urgency track.
    // On-screen (toast) duration for an app, in seconds; -1 = never auto-dismiss.
    function timeoutFor(app, crit) {
        const v = (crit ? appTimeoutsCrit : appTimeouts)[app || ""];
        return (v === undefined || v === null) ? (crit ? defaultTimeoutCrit : defaultTimeout) : v;
    }
    function hasTimeout(app, crit) { return (crit ? appTimeoutsCrit : appTimeouts)[app || ""] !== undefined; }
    function setAppTimeout(app, secs, crit) { _setOverride(crit ? "appTimeoutsCrit" : "appTimeouts", app, secs); }
    function setDefaultTimeout(secs, crit) {
        if (crit) defaultTimeoutCrit = secs; else defaultTimeout = secs;
        _save();
    }

    // Auto-dismiss age for an app, in seconds; 0 = off.
    function autoDismissFor(app, crit) {
        const v = (crit ? appAutoDismissCrit : appAutoDismiss)[app || ""];
        return (v === undefined || v === null) ? (crit ? defaultAutoDismissCrit : defaultAutoDismiss) : v;
    }
    function hasAutoDismiss(app, crit) { return (crit ? appAutoDismissCrit : appAutoDismiss)[app || ""] !== undefined; }
    function setAppAutoDismiss(app, secs, crit) { _setOverride(crit ? "appAutoDismissCrit" : "appAutoDismiss", app, secs); pruneOld(); }
    function setDefaultAutoDismiss(secs, crit) {
        if (crit) defaultAutoDismissCrit = secs; else defaultAutoDismiss = secs;
        _save();
        pruneOld();
    }

    // Drop history (and any live retention) older than each entry's app's
    // auto-dismiss age (per-app override, else the global default).
    function pruneOld() {
        const now = Date.now();
        const keep = [], drop = [];
        for (const e of history) {
            const ad = autoDismissFor(e.appName, e.urgency === NotificationUrgency.Critical);
            (ad > 0 && e.time < now - ad * 1000) ? drop.push(e) : keep.push(e);
        }
        if (drop.length === 0)
            return;
        for (const e of drop)
            _drop(e.id);
        history = keep;
        _save();
    }
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.pruneOld()
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
            if (app && root.knownApps.indexOf(app) < 0)
                root.knownApps = [...root.knownApps, app];
            const id = root._nextId++;
            const entry = {
                id: id,
                summary: n.summary ?? "",
                body: n.body ?? "",
                appName: app,
                desktopEntry: n.desktopEntry ?? "",
                appIcon: n.appIcon ?? "",
                image: n.image ?? "",
                urgency: n.urgency,
                time: Date.now()
            };

            // A "block" rule discards the notification outright — no toast, no
            // sound, not even a history entry.
            const sm = root.silenceMode(entry);
            if (sm === "block") {
                n.tracked = false;
                return;
            }

            if (root.dnd || root.isMuted(app) || sm === "mute") {
                n.tracked = false; // record to history only, no toast / retention
            } else {
                n.tracked = true;  // retain alive for the center
                root._liveById[id] = n;
                root.toastQueue = [...root.toastQueue, entry];

                // Sound effect for a surfaced notification. Suppressed by DND/mute
                // (above) and by the app's own `suppress-sound` hint (e.g. media
                // players that play their own audio).
                const sup = n.hints && n.hints["suppress-sound"];
                if (!sup)
                    Sound.notify(n.urgency === NotificationUrgency.Critical);

                // quickshell destroys the Notification synchronously right after
                // `closed` fires (expiry / dismissal / client CloseNotification),
                // so every live ref must be pruned here. The queue holds only the
                // plain entry, so deferring its removal past destruction is safe.
                n.closed.connect(() => {
                    delete root._liveById[id];
                    Qt.callLater(() => root.removeToast(id));
                });

                // In-place updates (replaces_id — e.g. Discord coalescing
                // "3 new messages"): quickshell reuses the object, updates its
                // properties and does NOT re-emit `notification`. callLater
                // collapses the burst of change signals from one update into a
                // single refresh.
                const refresh = () => Qt.callLater(() => root._refresh(id));
                n.summaryChanged.connect(refresh);
                n.bodyChanged.connect(refresh);
                n.imageChanged.connect(refresh);
                n.urgencyChanged.connect(refresh);
                n.actionsChanged.connect(refresh);
                n.hintsChanged.connect(refresh);
            }

            // Prepend, cap at 50, fully dropping anything evicted.
            const trimmed = [entry, ...root.history];
            for (const e of trimmed.slice(50))
                root._drop(e.id);
            root.history = trimmed.slice(0, 50);
            root._save();
        }
    }

    function removeToast(id) { toastQueue = toastQueue.filter(e => e.id !== id); }

    // Re-sync after an in-place update (replaces_id): rebuild the snapshot, move
    // it to the front of history, and resurface the toast with a fresh timer and
    // sound — an update is effectively the newest notification.
    function _refresh(id) {
        const n = _liveById[id];
        if (!n)
            return; // closed before the deferred refresh ran
        const entry = {
            id: id,
            summary: n.summary ?? "",
            body: n.body ?? "",
            appName: n.appName ?? "",
            desktopEntry: n.desktopEntry ?? "",
            appIcon: n.appIcon ?? "",
            image: n.image ?? "",
            urgency: n.urgency,
            time: Date.now()
        };

        // Re-apply silence rules to the new content. Untracking destroys n
        // without a `closed` signal, so clean up the live refs explicitly.
        const sm = silenceMode(entry);
        if (sm === "block") {
            delete _liveById[id];
            toastQueue = toastQueue.filter(e => e.id !== id);
            history = history.filter(e => e.id !== id);
            n.tracked = false;
            _save();
            return;
        }

        history = [entry, ...history.filter(e => e.id !== id)].slice(0, 50);
        _save();

        if (dnd || isMuted(entry.appName) || sm === "mute") {
            toastQueue = toastQueue.filter(e => e.id !== id);
            return;
        }
        // Replace in place if still visible, else resurface at the end. Either
        // way the fresh entry object recreates the delegate, restarting its
        // auto-dismiss timer and replaying the entry animation.
        const visible = toastQueue.some(e => e.id === id);
        toastQueue = visible ? toastQueue.map(e => e.id === id ? entry : e) : [...toastQueue, entry];
        const sup = n.hints && n.hints["suppress-sound"];
        if (!sup)
            Sound.notify(n.urgency === NotificationUrgency.Critical);
    }

    // Single dismissal path: dismiss the live notification (if any) and prune it
    // from every place it can linger (toastQueue + _liveById). Callers update
    // `history` separately.
    function _drop(id) {
        const n = _liveById[id];
        if (n)
            n.dismiss(); // its closed handler also prunes _liveById
        toastQueue = toastQueue.filter(e => e.id !== id);
        delete _liveById[id];
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
                root.silenceRules = d.silenceRules || [];
                root.knownApps = d.knownApps || [];
                root.appTimeouts = d.appTimeouts || ({});
                root.defaultTimeout = (d.defaultTimeout === undefined) ? 5 : d.defaultTimeout;
                root.appTimeoutsCrit = d.appTimeoutsCrit || ({});
                root.defaultTimeoutCrit = (d.defaultTimeoutCrit === undefined) ? -1 : d.defaultTimeoutCrit;
                root.appAutoDismiss = d.appAutoDismiss || ({});
                root.defaultAutoDismiss = d.defaultAutoDismiss || 0;
                root.appAutoDismissCrit = d.appAutoDismissCrit || ({});
                root.defaultAutoDismissCrit = d.defaultAutoDismissCrit || 0;
                let mx = 0;
                for (const e of root.history)
                    mx = Math.max(mx, e.id || 0);
                root._nextId = mx + 1;
                let rmx = 0;
                for (const r of root.silenceRules)
                    rmx = Math.max(rmx, r.id || 0);
                root._nextRuleId = rmx + 1;
                root.pruneOld(); // clear anything already past its auto-dismiss age
            } catch (e) {}
        }
    }
    function _save() {
        store.setText(JSON.stringify({
            history: history,
            mutedApps: mutedApps,
            silenceRules: silenceRules,
            knownApps: knownApps,
            appTimeouts: appTimeouts,
            defaultTimeout: defaultTimeout,
            appTimeoutsCrit: appTimeoutsCrit,
            defaultTimeoutCrit: defaultTimeoutCrit,
            appAutoDismiss: appAutoDismiss,
            defaultAutoDismiss: defaultAutoDismiss,
            appAutoDismissCrit: appAutoDismissCrit,
            defaultAutoDismissCrit: defaultAutoDismissCrit
        }));
    }
}
