// Scene: the whole shell, stepping through the notifications settings view,
// the control → confirm morph (never confirmed), the first tray item's menu and
// the clock panel. External IPC (cheatsheet, cameraImport) is driven by the
// scene itself via `qs ipc -p <root> call …` (separate processes, like the real callers).
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import qs.bar
import qs.island
import qs.overlays
import qs.panels
import qs.services
import qs.dev

ShellRoot {
    id: shell
    readonly property var scr: Quickshell.screens[0]

    Bar { id: bar; modelData: shell.scr; exclusionMode: ExclusionMode.Ignore }
    Island {
        modelData: shell.scr
        ControlPanel { id: control }
        ConfirmPanel { id: confirmPanel }
        NotificationsPanel { id: notif }
        ClockPanel {}
        TrayMenuPanel {}
    }
    KeybindSheet { modelData: shell.scr }
    CameraImportOsd { modelData: shell.scr }

    Timer { running: true; interval: 500; onTriggered: { notif.view = 1; Popouts.open(shell.scr, "notifications", bar.triggers.notifications); } }
    Snap { name: "notif-settings"; region: "1300,0 840x620"; delay: 1500 }
    Timer { running: true; interval: 1700; onTriggered: Popouts.open(shell.scr, "control", bar.triggers.control) }
    Timer { running: true; interval: 2500; onTriggered: control.requestPower("reboot") }
    Snap { name: "confirm-morph"; region: "2840,0 600x520"; delay: 2600 }
    Snap { name: "confirm"; region: "2840,0 600x520"; delay: 3200 }
    Timer {
        running: true
        interval: 3400
        onTriggered: {
            console.log("TEST confirm pending=" + Session.pending + " open=" + Popouts.current(shell.scr));
            Popouts.close(shell.scr); // cancel — never confirm in a test
        }
    }
    Timer {
        running: true
        interval: 3800
        onTriggered: {
            console.log("TEST after-cancel pending='" + Session.pending + "'");
            // The folding card keeps its label once pending is cleared.
            console.log("TEST confirm label-kept=" + confirmPanel.reboot);
            const items = SystemTray.items.values;
            console.log("TEST tray items=" + items.map(i => i.id).join(","));
            const it = items.find(i => i.hasMenu);
            if (it) {
                TrayMenu.show(it);
                Popouts.open(shell.scr, "traymenu", bar.triggers.control);
            }
        }
    }
    Snap { name: "traymenu"; region: "2840,0 600x520"; delay: 4600 }
    Timer { running: true; interval: 4800; onTriggered: Popouts.open(shell.scr, "clock", bar.triggers.clock) }
    Snap { name: "clock"; region: "1300,0 840x420"; delay: 5600 }
    Timer { running: true; interval: 5800; onTriggered: Popouts.close(shell.scr) }
    // External IPC, exactly as the watcher / camera-import script call it.
    function ipc(args) {
        Quickshell.execDetached(["qs", "ipc", "-p", Quickshell.shellDir, "call"].concat(args));
    }
    Timer { running: true; interval: 6000; onTriggered: shell.ipc(["cheatsheet", "open"]) }
    Timer { running: true; interval: 6900; onTriggered: shell.ipc(["cheatsheet", "close"]) }
    Timer { running: true; interval: 7000; onTriggered: shell.ipc(["cameraImport", "start", "12"]) }
    Timer { running: true; interval: 7300; onTriggered: shell.ipc(["cameraImport", "progress", "5", "12"]) }
    Timer { running: true; interval: 7900; onTriggered: console.log("TEST camera phase=" + CameraImport.phase + " done=" + CameraImport.done + "/" + CameraImport.total + " cheatsheet=" + Cheatsheet.shown) }
    Snap { name: "cheatsheet"; delay: 6700 }
    Snap { name: "camera"; region: "1520,30 400x80"; delay: 7600 }
    Quit { delay: 9500 }
}
