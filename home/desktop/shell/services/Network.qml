pragma Singleton

// NetworkManager state (Quickshell.Networking): the active link, the Wi-Fi radio
// and its networks, the wired device, plus local / external IP lookups.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

Singleton {
    id: root

    readonly property var devices: Networking.devices?.values ?? []
    readonly property var activeDevice: devices.find(d => d.connected) ?? null
    readonly property bool online: activeDevice !== null
    // The Wi-Fi radio is the device with a scanner; the wired one has none.
    readonly property var wifiDevice: devices.find(d => d.scannerEnabled !== undefined) ?? null
    readonly property var ethDevice: devices.find(d => d.scannerEnabled === undefined) ?? null
    readonly property bool activeIsWifi: activeDevice ? activeDevice.scannerEnabled !== undefined : false
    readonly property bool ethConnected: (online && !activeIsWifi) || (ethDevice?.connected ?? false)
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property string connectedSsid: (wifiDevice?.networks?.values ?? []).find(n => n.connected)?.name ?? ""
    // Networks sorted connected-first, then by signal strength.
    readonly property var wifiNetworks: {
        const nets = (wifiDevice?.networks?.values ?? []).slice();
        nets.sort((a, b) => (b.connected - a.connected) || ((b.signalStrength ?? 0) - (a.signalStrength ?? 0)));
        return nets;
    }

    readonly property string icon: !online ? "signal_wifi_off" : activeIsWifi ? "wifi" : "lan"

    function setWifiEnabled(on) {
        Networking.wifiEnabled = on;
    }
    // Scan only while someone is looking at the list (disabling the scanner
    // empties the network list).
    function setScanning(on) {
        if (wifiDevice)
            wifiDevice.scannerEnabled = on;
    }
    function signalIcon(s) {
        return s > 0.75 ? "signal_wifi_4_bar" : s > 0.4 ? "network_wifi_3_bar" : "network_wifi_1_bar";
    }

    // ── IP addresses (refreshed on demand, e.g. when the panel opens) ────────
    property string localIp: ""
    property string externalIp: ""
    property double _extIpAt: 0
    function refreshIps() {
        localIpProc.running = true;
        // The external IP costs a round-trip to api.ipify.org — reuse a
        // successful answer for five minutes.
        if (Date.now() - _extIpAt > 5 * 60 * 1000) {
            externalIp = "";
            extIpProc.running = true;
        }
    }
    Process {
        id: localIpProc
        // The source address of the default route = the IP used to reach the
        // internet, whatever the interface is called.
        command: ["sh", "-c", "ip -4 route get 1.1.1.1 2>/dev/null | grep -oP 'src \\K[0-9.]+' | head -1"]
        stdout: StdioCollector {
            onStreamFinished: root.localIp = text.trim()
        }
    }
    Process {
        id: extIpProc
        command: ["curl", "-s", "--max-time", "4", "https://api.ipify.org"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.externalIp = text.trim();
                if (root.externalIp !== "")
                    root._extIpAt = Date.now();
            }
        }
    }

    function openEditor() {
        Quickshell.execDetached(["nm-connection-editor"]);
    }
}
