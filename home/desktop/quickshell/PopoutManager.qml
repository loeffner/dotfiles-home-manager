pragma Singleton

// Single-open coordinator for the Material-3 cluster popouts, keyed by id. Each
// Popout binds its visibility to `openId === its id`, so switching is atomic:
// clicking another bar icon sets a new openId, which closes the previous popout
// and opens the new one in the same click (DankMaterialShell parity). The sole
// popup coordinator now that the legacy BarPopup/PopupState have been retired.
import QtQuick
import Quickshell

Singleton {
    id: root

    property string openId: ""
    readonly property bool anyOpen: openId !== ""

    function open(id) {
        openId = id;
    }
    function toggle(id) {
        openId = (openId === id) ? "" : id;
    }
    function close() {
        openId = "";
    }
}
