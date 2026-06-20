pragma Singleton

// niri integration without the external QML plugin: we follow niri's own JSON
// IPC event stream. `niri msg --json event-stream` dumps the current state on
// connect and then streams deltas, so workspaces and windows stay live.
// Actions (focus a workspace) are one-shot `niri msg action` calls.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Array of { id, idx, name, output, active, focused }, sorted by output+idx.
    property var workspaces: []
    property int focusedId: -1

    // Logical width of the primary output in niri pixels — used by the minimap
    // to convert tile_size[0] into bar pixels. Defaults to 1920 until the
    // outputs query returns.
    property int outputWidth: 1920

    // Array of { id, workspaceId, focused, col, row, floating } for the minimap.
    property var windows: []
    property var _wins: ({})

    function ingestList(list) {
        const ws = list.map(w => ({
                    id: w.id,
                    idx: w.idx,
                    name: w.name,
                    output: w.output,
                    active: w.is_active,
                    focused: w.is_focused
                })).sort((a, b) => a.output === b.output
                    ? a.idx - b.idx
                    : (a.output || "").localeCompare(b.output || ""));
        workspaces = ws;
        const f = ws.find(w => w.focused) || ws.find(w => w.active);
        focusedId = f ? f.id : -1;
    }

    // WorkspaceActivated only names the newly-active id; recompute active/focused
    // for that workspace's output without dropping the rest of the list.
    function activate(id, focused) {
        const target = workspaces.find(w => w.id === id);
        if (!target)
            return;
        const out = target.output;
        workspaces = workspaces.map(w => {
            const nw = Object.assign({}, w);
            if (w.output === out)
                nw.active = (w.id === id);
            if (focused)
                nw.focused = (w.id === id);
            return nw;
        });
        if (focused)
            focusedId = id;
    }

    // ── Window tracking ───────────────────────────────────────────────────
    // Maintained incrementally from the event stream (no polling). The layout
    // object — pos_in_scrolling_layout [column, row] and tile_size [w, h] — is
    // absent for floating windows.
    function _layoutInto(rec, layout) {
        const pos = layout && layout.pos_in_scrolling_layout ? layout.pos_in_scrolling_layout : null;
        const sz = layout && layout.tile_size ? layout.tile_size : null;
        rec.col = pos ? pos[0] : null;
        rec.row = pos ? pos[1] : null;
        rec.tileWidth = sz ? sz[0] : 0;
        rec.tileHeight = sz ? sz[1] : 0;
    }
    function _putWindow(w) {
        const rec = {
            id: w.id,
            workspaceId: w.workspace_id,
            focused: !!w.is_focused,
            floating: !!w.is_floating
        };
        _layoutInto(rec, w.layout);
        _wins[w.id] = rec;
    }
    function _closeWindow(id) {
        delete _wins[id];
    }
    // WindowFocusChanged carries only the newly-focused id (or null).
    function _focusWindow(id) {
        for (const k in _wins)
            _wins[k].focused = (_wins[k].id === id);
    }
    // WindowLayoutsChanged: array of [windowId, layout] pairs (tile resizes etc.).
    function _applyLayouts(changes) {
        if (!changes)
            return;
        for (const ch of changes) {
            const rec = _wins[ch[0]];
            if (rec)
                _layoutInto(rec, ch[1]);
        }
    }
    function _resetWindows(list) {
        _wins = {};
        for (const w of list)
            _putWindow(w);
    }
    function _emitWindows() {
        windows = Object.keys(_wins).map(k => _wins[k]);
    }

    function focusWorkspace(idx) {
        Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(idx)]);
    }

    // Query the logical output width once at startup.
    Process {
        command: ["niri", "msg", "--json", "outputs"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const outs = JSON.parse(text);
                    // Use the widest logical output (handles multi-monitor; the
                    // minimap only shows one workspace at a time anyway).
                    let w = 0;
                    for (const o of outs)
                        if (o.logical && o.logical.width > w)
                            w = o.logical.width;
                    if (w > 0)
                        root.outputWidth = w;
                } catch (e) {}
            }
        }
    }

    // Workspaces + windows: follow the event stream for instant updates. On
    // connect niri dumps current state (WorkspacesChanged + WindowsChanged), then
    // streams deltas — so both stay live with no polling.
    Process {
        running: true
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const ev = JSON.parse(line);
                    if (ev.WorkspacesChanged) {
                        root.ingestList(ev.WorkspacesChanged.workspaces);
                    } else if (ev.WorkspaceActivated) {
                        root.activate(ev.WorkspaceActivated.id, ev.WorkspaceActivated.focused);
                    } else if (ev.WindowsChanged) {
                        root._resetWindows(ev.WindowsChanged.windows);
                        root._emitWindows();
                    } else if (ev.WindowOpenedOrChanged) {
                        root._putWindow(ev.WindowOpenedOrChanged.window);
                        root._emitWindows();
                    } else if (ev.WindowClosed) {
                        root._closeWindow(ev.WindowClosed.id);
                        root._emitWindows();
                    } else if (ev.WindowFocusChanged) {
                        root._focusWindow(ev.WindowFocusChanged.id);
                        root._emitWindows();
                    } else if (ev.WindowLayoutsChanged) {
                        root._applyLayouts(ev.WindowLayoutsChanged.changes);
                        root._emitWindows();
                    }
                } catch (e)
                // Non-JSON / partial line — ignore.
                {}
            }
        }
    }
}
