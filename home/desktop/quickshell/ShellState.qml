pragma Singleton

// Global visibility flag for the full-screen cheatsheet overlay. Distinct from
// PopoutManager, which manages the bar's cluster + clock dropdowns.
import QtQuick
import Quickshell

Singleton {
    property bool cheatOpen: false // pictographic keybind cheatsheet (hold Super)

    // Close any open popout when the cheatsheet takes over the screen.
    onCheatOpenChanged: if (cheatOpen) PopoutManager.close()
}
