pragma Singleton

// niri integration via its JSON IPC (no QML plugin): `niri msg --json
// event-stream` dumps the current state on connect and then streams deltas, so
// workspaces, windows and the keyboard layout stay live without polling.
// Actions are one-shot `niri msg action` calls.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // [{ id, idx, name, output, active, focused }] sorted by output, then idx.
    property var workspaces: []
    property int focusedWorkspaceId: -1
    // [{ id, workspaceId, focused, floating, appId, title, col, row, tileWidth, tileHeight }]
    property var windows: []
    // Widest logical output width (niri px); the minimap scales tile widths by it.
    property int outputWidth: 1920
    // Configured xkb layout names and the active index (0 = the default).
    property var layoutNames: []
    property int layoutIdx: 0

    function workspacesOn(output) {
        const own = workspaces.filter(w => w.output === output);
        return own.length > 0 ? own : workspaces; // unknown output: show all
    }

    // ── Actions ──────────────────────────────────────────────────────────────
    function focusWorkspace(idx) {
        Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(idx)]);
    }
    function focusWindow(id) {
        Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", String(id)]);
    }
    function switchLayout() {
        Quickshell.execDetached(["niri", "msg", "action", "switch-layout", "next"]);
    }

    // Focus the window that best matches an app identity — a notification's
    // `desktop-entry` hint / app name, or a tray item's id / title. Matches
    // desktopEntry against app_id (exact, then reverse-DNS suffix either way),
    // then the app name against app_id / title. Returns whether one was found.
    function focusByApp(desktopEntry, appName) {
        const norm = s => (s || "").toLowerCase();
        const de = norm(desktopEntry), an = norm(appName);
        let m = null;
        if (de)
            m = windows.find(w => norm(w.appId) === de)
                || windows.find(w => norm(w.appId).endsWith("." + de) || de.endsWith("." + norm(w.appId)));
        if (!m && an)
            m = windows.find(w => norm(w.appId) === an)
                || windows.find(w => norm(w.appId).indexOf(an) >= 0)
                || windows.find(w => norm(w.title).indexOf(an) >= 0);
        if (m)
            focusWindow(m.id);
        return !!m;
    }

    // ── State tracking ───────────────────────────────────────────────────────
    function _setWorkspaces(list) {
        workspaces = list.map(w => ({
                    "id": w.id,
                    "idx": w.idx,
                    "name": w.name,
                    "output": w.output,
                    "active": w.is_active,
                    "focused": w.is_focused
                })).sort((a, b) => a.output === b.output ? a.idx - b.idx : (a.output || "").localeCompare(b.output || ""));
        const f = workspaces.find(w => w.focused) || workspaces.find(w => w.active);
        focusedWorkspaceId = f ? f.id : -1;
    }
    // WorkspaceActivated names only the new id: update its output's active flag
    // (and focus, if focused) without dropping the rest of the list.
    function _activateWorkspace(id, focused) {
        const target = workspaces.find(w => w.id === id);
        if (!target)
            return;
        workspaces = workspaces.map(w => Object.assign({}, w, {
                    "active": w.output === target.output ? w.id === id : w.active,
                    "focused": focused ? w.id === id : w.focused
                }));
        if (focused)
            focusedWorkspaceId = id;
    }

    // Windows are kept in a private map keyed by id and published as a fresh
    // array (so bindings re-evaluate) after every change.
    property var _wins: ({})
    function _record(w) {
        const pos = w.layout?.pos_in_scrolling_layout ?? null;
        const size = w.layout?.tile_size ?? null;
        return {
            "id": w.id,
            "workspaceId": w.workspace_id,
            "focused": !!w.is_focused,
            "floating": !!w.is_floating,
            "appId": w.app_id || "",
            "title": w.title || "",
            "col": pos ? pos[0] : null,
            "row": pos ? pos[1] : null,
            "tileWidth": size ? size[0] : 0,
            "tileHeight": size ? size[1] : 0
        };
    }
    function _publish() {
        windows = Object.keys(_wins).map(k => _wins[k]);
    }

    function _handle(ev) {
        if (ev.WorkspacesChanged) {
            _setWorkspaces(ev.WorkspacesChanged.workspaces);
        } else if (ev.WorkspaceActivated) {
            _activateWorkspace(ev.WorkspaceActivated.id, ev.WorkspaceActivated.focused);
        } else if (ev.WindowsChanged) {
            _wins = {};
            for (const w of ev.WindowsChanged.windows)
                _wins[w.id] = _record(w);
            _publish();
        } else if (ev.WindowOpenedOrChanged) {
            const w = ev.WindowOpenedOrChanged.window;
            _wins[w.id] = _record(w);
            _publish();
        } else if (ev.WindowClosed) {
            delete _wins[ev.WindowClosed.id];
            _publish();
        } else if (ev.WindowFocusChanged) {
            for (const k in _wins)
                _wins[k].focused = _wins[k].id === ev.WindowFocusChanged.id;
            _publish();
        } else if (ev.WindowLayoutsChanged) {
            for (const [id, layout] of ev.WindowLayoutsChanged.changes || []) {
                const old = _wins[id];
                if (old)
                    _wins[id] = Object.assign(_record({ "id": id, "layout": layout }), {
                        "workspaceId": old.workspaceId,
                        "focused": old.focused,
                        "floating": old.floating,
                        "appId": old.appId,
                        "title": old.title
                    });
            }
            _publish();
        } else if (ev.KeyboardLayoutsChanged) {
            layoutNames = ev.KeyboardLayoutsChanged.keyboard_layouts.names;
            layoutIdx = ev.KeyboardLayoutsChanged.keyboard_layouts.current_idx;
        } else if (ev.KeyboardLayoutSwitched) {
            layoutIdx = ev.KeyboardLayoutSwitched.idx;
        }
    }

    Process {
        running: true
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    root._handle(JSON.parse(line));
                } catch (e) {
                    // Non-JSON / partial line — ignore.
                }
            }
        }
    }

    Process {
        running: true
        command: ["niri", "msg", "--json", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let w = 0;
                    for (const o of Object.values(JSON.parse(text)))
                        if (o.logical && o.logical.width > w)
                            w = o.logical.width;
                    if (w > 0)
                        root.outputWidth = w;
                } catch (e) {}
            }
        }
    }
}
