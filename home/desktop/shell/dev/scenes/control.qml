// Scene: control-panel behaviour — expand the output picker and the Wi-Fi list
// (screenshots), check Wi-Fi scanning follows the list, then press Escape (via
// wtype, only once the island verifiably holds keyboard focus) and check the
// panel closed and scanning stopped.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.bar
import qs.island
import qs.panels
import qs.services
import qs.dev

ShellRoot {
    id: shell
    readonly property var scr: Quickshell.screens[0]
    property var panel: null

    Bar { id: bar; modelData: shell.scr; exclusionMode: ExclusionMode.Ignore }
    Island {
        id: island
        modelData: shell.scr
        ControlPanel { id: control }
        ConfirmPanel {}
    }

    function log(tag) {
        console.log("TEST " + tag + " open=" + Popouts.current(shell.scr) + " expanded=" + control.expanded
            + " scanning=" + (Network.wifiDevice?.scannerEnabled ?? "n/a") + " islandKeyboard=" + island.hasKeyboard);
    }

    Timer { running: true; interval: 500; onTriggered: Popouts.open(shell.scr, "control", bar.triggers.control) }
    Timer { running: true; interval: 1200; onTriggered: { control.expanded = "out"; shell.log("out"); } }
    Snap { name: "picker"; region: "2840,0 600x720"; delay: 1700 }
    Timer { running: true; interval: 1900; onTriggered: { control.expanded = "wifi"; shell.log("wifi"); } }
    Snap { name: "wifi"; region: "2840,0 600x900"; delay: 3200 }
    Timer {
        running: true
        interval: 3500
        onTriggered: {
            shell.log("before-esc");
            if (island.hasKeyboard)
                Quickshell.execDetached([Quickshell.env("QS_DEV_WTYPE"), "-k", "Escape"]);
            else
                console.log("TEST SKIP escape: island has no keyboard focus");
        }
    }
    Timer { running: true; interval: 4200; onTriggered: shell.log("after-esc") }
    Quit { delay: 4400 }
}
