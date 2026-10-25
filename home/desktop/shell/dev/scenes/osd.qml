// Volume OSD: grows out of the control pill on a volume change, folds back after
// the hide delay, and stays away while a panel is open. Snaps the OSD (morphing
// and settled) next to the open control panel for a look comparison.
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
    readonly property string region: (shell.scr.width - 600) + ",0 600x200"

    Bar { id: bar; modelData: shell.scr; exclusionMode: ExclusionMode.Ignore }
    VolumeOsd { id: osd; modelData: shell.scr; anchorItem: bar.triggers.control }
    Island {
        modelData: shell.scr
        ControlPanel {}
    }

    Timer {
        running: true
        interval: 800
        onTriggered: {
            osd.show("volume");
            const pillX = bar.triggers.control.mapToItem(null, 0, 0).x;
            console.log("TEST osd right-side=" + (osd.cardX > shell.scr.width / 2) + " under-pill=" + (osd.cardX <= pillX && osd.cardX + osd.cardWidth >= pillX + bar.triggers.control.width));
        }
    }
    Snap { name: "osd-morph"; region: shell.region; delay: 900 }
    Snap { name: "osd"; region: shell.region; delay: 1400 }
    Timer { running: true; interval: 3200; onTriggered: console.log("TEST osd hidden-after-delay=" + !osd.shown) }

    Timer { running: true; interval: 3600; onTriggered: Popouts.open(shell.scr, "control", bar.triggers.control) }
    Timer {
        running: true
        interval: 4200
        onTriggered: {
            osd.show("volume");
            console.log("TEST osd suppressed-while-panel-open=" + !osd.shown);
        }
    }
    Snap { name: "control"; region: (shell.scr.width - 600) + ",0 600x700"; delay: 4400 }
    Timer { running: true; interval: 4800; onTriggered: Popouts.close(shell.scr) }
}
