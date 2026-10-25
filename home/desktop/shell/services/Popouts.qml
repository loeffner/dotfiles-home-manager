pragma Singleton

// Which popout panel is open on which screen. One panel per screen at a time;
// opening another panel on the same screen replaces it (the island window morphs
// between them). Keyed by screen name so monitors never open each other's
// panels. Panel ids: "control", "notifications", "clipboard", "processes",
// "clock", "traymenu", "confirm".
import QtQuick
import Quickshell

Singleton {
    id: root

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
