// Scene (run with --private-bus): real notifications through the new daemon.
// Sends a normal, a critical, an actionable and a rule-blocked notification,
// then an in-place update (replaces_id) of the first; prints the store's state
// and screenshots the toasts + bell.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.bar
import qs.overlays
import qs.services
import qs.dev

ShellRoot {
    id: shell
    Bar { id: bar; modelData: Quickshell.screens[0]; exclusionMode: ExclusionMode.Ignore }
    Toasts { modelData: Quickshell.screens[0] }

    function send(args) {
        Quickshell.execDetached(["notify-send"].concat(args));
    }
    function state(tag) {
        console.log("TEST " + tag + " toasts=" + Notifications.toasts.map(t => t.summary).join("|")
            + " history=" + Notifications.history.slice(0, 5).map(t => t.summary).join("|")
            + " live=" + Notifications.activeCount);
    }

    // notify-send -p prints the id, so the update can replace it.
    Process {
        id: first
        running: false
        command: ["notify-send", "-p", "-a", "TestApp", "First", "the first body"]
        stdout: StdioCollector {
            onStreamFinished: shell.firstId = text.trim()
        }
    }
    property string firstId: ""

    Timer { running: true; interval: 600; onTriggered: first.running = true }
    Timer { running: true; interval: 700; onTriggered: shell.send(["-a", "TestApp", "-u", "critical", "Critical one", "stays on screen"]) }
    Timer { running: true; interval: 800; onTriggered: shell.send(["-a", "Other", "-A", "open=Open it", "With action", "has a button"]) }
    Timer { running: true; interval: 900; onTriggered: shell.send(["-a", "Spam", "Blocked", "this is unread and relevant"]) }
    Timer { running: true; interval: 1300; onTriggered: shell.state("after-send") }
    Snap { name: "toasts"; region: "3000,0 440x420"; delay: 1350 }
    Snap { name: "bell"; region: "1420,0 600x30"; delay: 1350 }
    Timer { running: true; interval: 1500; onTriggered: shell.send(["-a", "TestApp", "-r", shell.firstId, "First (updated)", "replaced in place"]) }
    Timer { running: true; interval: 1900; onTriggered: shell.state("after-update") }
    // defaultTimeout is 2 s (migrated settings): normal toasts gone by now,
    // the critical one (10 s) still up.
    Timer { running: true; interval: 4300; onTriggered: shell.state("after-timeout") }
    // Burst: five at once — none may be lost from history.
    Timer {
        running: true
        interval: 4400
        onTriggered: {
            for (let i = 1; i <= 5; i++)
                shell.send(["-a", "Burst", "Burst " + i, "x"]);
        }
    }
    Timer { running: true; interval: 5200; onTriggered: console.log("TEST burst history=" + Notifications.history.filter(e => e.appName === "Burst").length + "/5 file-has=" + (file.text().match(/Burst \d/g) || []).length) }
    FileView { id: file; path: Settings.stateDir + "/notifications.json"; watchChanges: false; printErrors: false; blockLoading: true }
    Timer { running: true; interval: 5100; onTriggered: file.reload() }
    Quit { delay: 5400 }
}
