pragma Singleton

// Which popout panel is open on which screen. One panel per screen at a time;
// opening another panel on the same screen replaces it (the island window morphs
// between them). Keyed by screen name so monitors never open each other's
// panels. Panel ids: "control", "notifications", "clipboard", "processes",
// "clock", "traymenu", "confirm", "mail".
//
// Keyboard: `qs ipc call popouts toggle <id>` (niri binds, niri/binds.nix)
// toggles a panel on the focused monitor, hanging from the bar item a click
// would use. Those are asked for when needed (anchorsRequested → each Bar
// calls registerAnchors()), not kept from startup: a live reload carries this
// singleton's state over, and stored items would point at the old, destroyed
// bars.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    signal anchorsRequested
    property var _anchors: ({}) // screen name -> { panel id -> bar Item }

    function registerAnchors(screen, anchors) {
        _anchors[screen.name] = anchors;
    }
    function _anchorFor(screen, id) {
        _anchors = {};
        anchorsRequested(); // the bars answer synchronously
        return _anchors[screen?.name]?.[id] ?? null;
    }
    // The monitor with niri's focused workspace (the first one if unknown).
    function focusedScreen() {
        const ws = Niri.workspaces.find(w => w.id === Niri.focusedWorkspaceId);
        return Quickshell.screens.find(s => s.name === ws?.output) ?? Quickshell.screens[0];
    }

    IpcHandler {
        target: "popouts"
        function toggle(id: string): string {
            const screen = root.focusedScreen();
            const anchor = root._anchorFor(screen, id);
            if (!anchor)
                return "unknown popout: " + id;
            root.toggle(screen, id, anchor);
            return root.isOpen(screen, id) ? "opened" : "closed";
        }
        function close(): string {
            root.close(root.focusedScreen());
            return "ok";
        }
    }

    // screen name -> { id, anchor } where anchor is the bar Item the panel hangs
    // from. Replaced wholesale on every change so bindings re-evaluate.
    property var _open: ({})

    function current(screen) {
        return _open[screen?.name ?? ""]?.id ?? "";
    }
    function anchorOf(screen) {
        return _open[screen?.name ?? ""]?.anchor ?? null;
    }
    function isOpen(screen, id) {
        return current(screen) === id;
    }
    // Open on any screen — services use this to poll faster only while visible.
    function anyOpen(id) {
        return Object.values(_open).some(e => e.id === id);
    }

    function open(screen, id, anchor) {
        const o = Object.assign({}, _open);
        o[screen.name] = { "id": id, "anchor": anchor };
        _open = o;
    }
    function toggle(screen, id, anchor) {
        if (isOpen(screen, id))
            close(screen);
        else
            open(screen, id, anchor);
    }
    // Close the panel on one screen, or on every screen when none is given.
    function close(screen) {
        if (!screen) {
            _open = {};
            return;
        }
        const o = Object.assign({}, _open);
        delete o[screen.name];
        _open = o;
    }
}
