pragma Singleton

// Bluetooth (Quickshell.Bluetooth): the default adapter, its devices, and a
// single click action per device (disconnect / connect / pair).
import QtQuick
import Quickshell
import Quickshell.Bluetooth as QsBt

Singleton {
    id: root

    readonly property var adapter: QsBt.Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property var devices: adapter?.devices?.values ?? []
    readonly property var connected: devices.filter(d => d.connected)

    readonly property string icon: connected.length > 0 ? "bluetooth_connected" : enabled ? "bluetooth" : "bluetooth_disabled"
    readonly property string summary: !enabled ? "Off" : connected.length > 0 ? connected.map(d => d.name).join(", ") : "No devices"

    function setEnabled(on) {
        if (adapter)
            adapter.enabled = on;
    }
    // Discover only while the device list is shown.
    function setDiscovering(on) {
        if (adapter)
            adapter.discovering = on && enabled;
    }
    function activate(d) {
        if (d.connected)
            d.disconnect();
        else if (d.paired || d.bonded)
            d.connect();
        else
            d.pair();
    }
    function openManager() {
        Quickshell.execDetached(["blueman-manager"]);
    }
}
