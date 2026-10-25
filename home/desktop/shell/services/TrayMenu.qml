pragma Singleton

// The tray menu being shown (rendered by panels/TrayMenuPanel from
// QsMenuOpener — the items' own SNI activate()/display() are unreliable on
// niri). `stack` holds the submenus navigated into; `current` is what to show.
// One menu at a time across screens.
import QtQuick
import Quickshell

Singleton {
    id: root
    property var menu: null // the item's root menu handle
    property var stack: []
    readonly property var current: stack.length > 0 ? stack[stack.length - 1] : menu

    function show(item) {
        stack = [];
        menu = item.menu;
    }
    function enter(entry) {
        stack = [...stack, entry];
    }
    function back() {
        stack = stack.slice(0, -1);
    }
}
