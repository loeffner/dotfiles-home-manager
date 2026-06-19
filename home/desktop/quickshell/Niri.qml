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
    // pos_in_scrolling_layout is [column, row]; absent for floating windows.
    function _putWindow(w) {
        const pos = w.layout && w.layout.pos_in_scrolling_layout ? w.layout.pos_in_scrolling_layout : null;
        const sz = w.layout && w.layout.tile_size ? w.layout.tile_size : null;
        _wins[w.id] = {
            id: w.id,
            workspaceId: w.workspace_id,
            focused: !!w.is_focused,
            col: pos ? pos[0] : null,
            row: pos ? pos[1] : null,
            floating: !!w.is_floating,
            tileWidth: sz ? sz[0] : 0,
            tileHeight: sz ? sz[1] : 0
        };
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

    // Workspaces: follow the event stream for instant updates on switch.
    Process {
        running: true
        command: ["niri", "msg", "--json", "event-stream"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    const ev = JSON.parse(line);
                    if (ev.WorkspacesChanged)
                        root.ingestList(ev.WorkspacesChanged.workspaces);
                    else if (ev.WorkspaceActivated)
                        root.activate(ev.WorkspaceActivated.id, ev.WorkspaceActivated.focused);
                    else if (ev.WindowsChanged || ev.WindowOpenedOrChanged || ev.WindowClosed || ev.WindowFocusChanged || ev.WindowLayoutsChanged)
                        winQuery.running = true; // refresh the window snapshot promptly
                } catch (e)
                // Non-JSON / partial line — ignore.
                {}
            }
        }
    }

    // Windows: poll `niri msg --json windows` (a known-good shape) for the
    // minimap. A short poll + event-driven refresh keeps it current without
    // depending on the exact event-stream window event names.
    Process {
        id: winQuery
        command: ["niri", "msg", "--json", "windows"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const arr = JSON.parse(text);
                    root._wins = {};
                    for (const w of arr)
                        root._putWindow(w);
                    root._emitWindows();
                } catch (e)
                {}
            }
        }
    }

    Timer {
        id: windowPoll
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: winQuery.running = true
    }
}
