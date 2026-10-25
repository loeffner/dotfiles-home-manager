// Scene: every service's live values, for comparison with dev/scenes/services-old.qml
// (run with --old). Both print one TEST line per area after things settle.
import QtQuick
import Quickshell
import qs.services

ShellRoot {
    Component.onCompleted: {
        Niri.workspaces; SystemStats.cpu; Player.active; Notifications.history; Clip.pins; Fans.fans; Audio.volume; Network.online; Bluetooth.enabled;
        Clip.refresh();
    }
    Timer {
        running: true
        interval: 2500
        onTriggered: {
            console.log("TEST niri ws=" + Niri.workspaces.map(w => w.idx + (w.focused ? "*" : "")).join(",") + " wins=" + Niri.windows.length + " outW=" + Niri.outputWidth + " layouts=" + JSON.stringify(Niri.layoutNames) + "@" + Niri.layoutIdx);
            console.log("TEST stats host=" + SystemStats.hostname + " cpuModel=" + SystemStats.cpuModel + " gpu=" + SystemStats.gpuName + " cpu>0=" + (SystemStats.cpu > 0) + " cpuTemp>0=" + (SystemStats.cpuTemp > 0));
            console.log("TEST fans hwmon=" + Fans.hwmon + " fans=" + Fans.fans.map(f => f.idx + ":" + (f.rpm > 0) + ":" + f.manual).join(","));
            console.log("TEST media active=" + (Player.active ? Player.active.identity : "none"));
            console.log("TEST notif history=" + Notifications.history.length + " firstId=" + (Notifications.history[0]?.id) + " live=" + Notifications.activeCount + " groups=" + Notifications.groupByApp(Notifications.history).length);
            console.log("TEST clip pins=" + Clip.pins.map(p => p.preview).join("|") + " history=" + Clip.history.length);
            console.log("TEST audio sink=" + Audio.deviceName(Audio.sink) + " vol=" + Audio.volume.toFixed(2) + " outs=" + Audio.outputs.length + " ins=" + Audio.inputs.length);
            console.log("TEST net online=" + Network.online + " icon=" + Network.icon + " eth=" + Network.ethConnected + " wifi=" + (Network.wifiDevice !== null) + " bt=" + Bluetooth.available + "/" + Bluetooth.enabled);
        }
    }
    Timer { running: true; interval: 3000; onTriggered: Qt.exit(0) }
}
