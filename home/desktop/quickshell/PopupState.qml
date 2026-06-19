pragma Singleton

// Ensures only one bar dropdown is open at a time: opening a popup closes the
// previously open one. BarPopup reports open/close transitions here.
// `anyOpen` is a reactive bool that the PopupBackdrop binds to.
import QtQuick
import Quickshell

Singleton {
    id: root
    property var current: null
    property bool anyOpen: false

    function opened(popup) {
        if (current && current !== popup)
            current.hide();
        current = popup;
        anyOpen = true;
    }

    function closed(popup) {
        if (current === popup) {
            current = null;
            anyOpen = false;
        }
    }
}
