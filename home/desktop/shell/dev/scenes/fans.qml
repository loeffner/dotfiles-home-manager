// Scene: the Fans write-hold logic WITHOUT touching hardware — calls the
// internal _hold() (no sysfs write), so the real fan keeps its old value and
// every poll disagrees: the held value must show at once, survive polls for
// ~3 s, then fall back to the real reading.
import QtQuick
import Quickshell
import qs.services

ShellRoot {
    id: shell
    Component.onCompleted: Fans.fans
    property int idx: -1
    property int real: -1
    function pct() {
        return Fans.fans.find(f => f.idx === shell.idx)?.pct;
    }
    Timer {
        running: true
        interval: 1200
        onTriggered: {
            const f = Fans.fans[0];
            shell.idx = f.idx;
            shell.real = f.pct;
            Fans._hold(f.idx, { "pct": (f.pct + 37) % 100 });
            console.log("TEST fan " + f.idx + " real=" + f.pct + " held=" + (f.pct + 37) % 100 + " shown-now=" + shell.pct());
        }
    }
    Timer { running: true; interval: 2000; onTriggered: console.log("TEST +0.8s (after confirm read) shown=" + shell.pct()) }
    Timer { running: true; interval: 3800; onTriggered: { Fans.expanded = true; console.log("TEST +2.6s shown=" + shell.pct()); } }
    Timer { running: true; interval: 5300; onTriggered: { console.log("TEST +4.1s (expired; re-read) shown=" + shell.pct() + " real=" + shell.real); Qt.exit(0); } }
    // Force a read after expiry (normal polling is 10 s while the panel is closed).
    Timer { running: true; interval: 4400; onTriggered: Fans._hold(-999, {}) }
}
