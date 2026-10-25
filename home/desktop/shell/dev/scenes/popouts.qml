// Scene: keyboard access to the popouts — `qs ipc call popouts toggle <id>`
// exactly as the niri binds call it (opens on the focused monitor, from the
// bar item a click would use; again closes; switching morphs; unknown ids are
// refused), then the hold-Super cheatsheet with its popout strip.
import QtQuick
import Quickshell
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

    Bar {
        modelData: shell.scr
        exclusionMode: ExclusionMode.Ignore
    }
    Island {
        id: island
        modelData: shell.scr
        ControlPanel {}
        ConfirmPanel {}
        NotificationsPanel {}
        ClipboardPanel {}
        MailPanel {}
        ProcessesPanel {}
        ClockPanel {}
        TrayMenuPanel {}
    }
    KeybindSheet {
        modelData: shell.scr
    }

    function ipc(args) {
        Quickshell.execDetached(["qs", "ipc", "-p", Quickshell.shellDir, "call"].concat(args));
    }
    function state(label) {
        console.log("TEST " + label + " open=" + (Popouts.current(Popouts.focusedScreen()) || "-") + " screen=" + Popouts.focusedScreen()?.name);
    }

    Timer { running: true; interval: 1500; onTriggered: shell.ipc(["popouts", "toggle", "mail"]) }
    Timer { running: true; interval: 2500; onTriggered: shell.state("after toggle mail") }
    Snap { name: "1-mail"; delay: 2400; region: "1100,0 1240x700" }
    Timer { running: true; interval: 2700; onTriggered: shell.ipc(["popouts", "toggle", "control"]) }
    Timer { running: true; interval: 3700; onTriggered: shell.state("after toggle control (switch)") }
    Snap { name: "2-control"; delay: 3600; region: "2400,0 1040x800" }
    Timer { running: true; interval: 3900; onTriggered: shell.ipc(["popouts", "toggle", "control"]) }
    Timer { running: true; interval: 4700; onTriggered: shell.state("after toggle control again") }
    Timer { running: true; interval: 4800; onTriggered: shell.ipc(["popouts", "toggle", "nope"]) }
    Timer { running: true; interval: 5500; onTriggered: shell.state("after unknown id") }
    Timer { running: true; interval: 5700; onTriggered: shell.ipc(["cheatsheet", "open"]) }
    Snap { name: "3-cheatsheet"; delay: 6600 }
    Timer { running: true; interval: 6900; onTriggered: shell.ipc(["cheatsheet", "close"]) }
    Quit { delay: 7600 }
}
