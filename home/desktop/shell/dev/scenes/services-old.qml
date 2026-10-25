// Scene (run with --old): the previous shell's service values, printed in the
// same format as dev/scenes/services.qml.
import QtQuick
import Quickshell

ShellRoot {
    Component.onCompleted: { Niri.workspaces; SystemStats.cpu; MediaThumb.active; Notifications.history; ClipStore.pins; Fans.fans; }
    Timer {
        running: true
        interval: 2500
        onTriggered: {
            console.log("TEST niri ws=" + Niri.workspaces.map(w => w.idx + (w.focused ? "*" : "")).join(",") + " wins=" + Niri.windows.length + " outW=" + Niri.outputWidth + " layouts=" + JSON.stringify(Niri.layoutNames) + "@" + Niri.layoutIdx);
            console.log("TEST stats host=" + SystemStats.hostname + " cpuModel=" + SystemStats.cpuModel + " gpu=" + SystemStats.gpuName + " cpu>0=" + (SystemStats.cpu > 0) + " cpuTemp>0=" + (SystemStats.cpuTemp > 0));
            console.log("TEST fans hwmon=" + Fans.hwmon + " fans=" + Fans.fans.map(f => f.idx + ":" + (f.rpm > 0) + ":" + f.manual).join(","));
            console.log("TEST media active=" + (MediaThumb.active ? MediaThumb.active.identity : "none"));
            console.log("TEST notif history=" + Notifications.history.length + " firstId=" + (Notifications.history[0]?.id) + " live=" + Notifications.history.filter(e => Notifications.liveFor(e.id) !== null).length + " groups=" + Notifications.grouped().length);
            console.log("TEST clip pins=" + ClipStore.pins.map(p => p.preview).join("|"));
        }
    }
    Timer { running: true; interval: 3000; onTriggered: Qt.exit(0) }
}
