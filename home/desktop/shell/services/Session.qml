pragma Singleton

// Session actions. Lock and suspend run immediately; reboot / power-off go
// through a confirmation (`pending`, shown by the "confirm" panel).
import QtQuick
import Quickshell

Singleton {
    id: root
    property string pending: "" // "reboot" | "poweroff" | ""

    function lock() {
        Quickshell.execDetached(["swaylock-themed"]); // daemonizes itself
    }
    function suspend() {
        Quickshell.execDetached(["systemctl", "suspend"]);
    }
    function request(action) {
        pending = action;
    }
    function confirm() {
        if (pending)
            Quickshell.execDetached(["systemctl", pending]);
        pending = "";
    }
    function cancel() {
        pending = "";
    }
}
