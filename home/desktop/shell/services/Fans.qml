pragma Singleton

// Fan monitoring + control via the Nuvoton nct6799 hwmon (ROG STRIX X670E-I).
// Reads RPM/PWM/mode; writes pwmN_enable (1 = manual; otherwise restores the
// fan's ORIGINAL auto mode captured before we touched it) and pwmN (0-255).
// Writing needs the pwm* sysfs group-writable (a NixOS udev rule handles that);
// without it, writes no-op. All sysfs access goes through scripts/fans.sh.
//
// Safety watchdog: if the CPU reaches safetyTemp while any fan is manual, every
// manual fan is reverted to its auto curve (+ a critical notification) — so a fan
// left pinned low can't cause overheating.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string hwmon: ""
    readonly property bool available: hwmon !== ""
    property var fans: []           // [{ idx, rpm, pct, manual }] (connected only)
    property bool expanded: false   // fan section shown in the Processes panel
    readonly property bool active: expanded && SystemStats.active // poll faster while visible
    property var _origEnable: ({})  // idx -> auto mode seen before we touched it
    property int safetyTemp: 85     // °C — revert manual fans to auto at/above this
    // Values just written, held until a read confirms them (or 3 s pass) so a
    // poll already in flight can't snap the slider / toggle back. idx -> { pct?, manual?, until }
    property var _held: ({})
    property bool _safetyTripped: false

    Process {
        running: true
        command: ["sh", Quickshell.shellPath("scripts/fans.sh"), "find"]
        stdout: StdioCollector {
            onStreamFinished: root.hwmon = text.trim()
        }
    }

    // Poll always (slow) so the safety watchdog always knows the fan state; faster
    // while the UI is open.
    Timer {
        interval: root.active ? 2000 : 10000
        running: root.available
        repeat: true
        triggeredOnStart: true
        onTriggered: readProc.running = true
    }

    Process {
        id: readProc
        command: root.hwmon === "" ? ["true"] : ["sh", Quickshell.shellPath("scripts/fans.sh"), "read", root.hwmon]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.trim().split("\n")) {
                    const p = line.split("|");
                    if (p.length < 4)
                        continue;
                    const idx = Number(p[0]);
                    const rpm = Number(p[1]) || 0;
                    const pw = Number(p[2]);
                    const en = Number(p[3]);
                    // Remember the pre-manual auto mode so "Auto" restores it exactly.
                    if (root._origEnable[idx] === undefined && isFinite(en) && en !== 1) {
                        const m = Object.assign({}, root._origEnable);
                        m[idx] = en;
                        root._origEnable = m;
                    }
                    // Skip unconnected headers: no tacho but pinned near full PWM.
                    if (rpm === 0 && pw >= 250)
                        continue;
                    out.push(root._applyHeld({
                        "idx": idx,
                        "rpm": rpm,
                        "pct": isFinite(pw) ? Math.round(pw / 255 * 100) : 0,
                        "manual": en === 1
                    }));
                }
                root.fans = out;
            }
        }
    }

    // Overlay a held write on a freshly read fan; drop the hold once the read
    // agrees or it expires.
    function _applyHeld(f) {
        const h = _held[f.idx];
        if (!h)
            return f;
        const agrees = (h.pct === undefined || h.pct === f.pct) && (h.manual === undefined || h.manual === f.manual);
        if (agrees || Date.now() > h.until) {
            const m = Object.assign({}, _held);
            delete m[f.idx];
            _held = m;
            return f;
        }
        return Object.assign({}, f, h.pct === undefined ? {} : { "pct": h.pct }, h.manual === undefined ? {} : { "manual": h.manual });
    }
    // Record a write: show it at once, hold it, and re-read shortly after.
    function _hold(idx, fields) {
        const m = Object.assign({}, _held);
        m[idx] = Object.assign({}, m[idx], fields, { "until": Date.now() + 3000 });
        _held = m;
        fans = fans.map(f => f.idx === idx ? _applyHeld(f) : f);
        confirmRead.restart();
    }
    Timer {
        id: confirmRead
        interval: 400
        onTriggered: readProc.running = true
    }

    function _autoMode(idx) {
        return root._origEnable[idx] !== undefined ? root._origEnable[idx] : 5;
    }
    function setManual(idx, on) {
        if (!available)
            return;
        Quickshell.execDetached(["sh", Quickshell.shellPath("scripts/fans.sh"), "enable", hwmon, String(idx), String(on ? 1 : root._autoMode(idx))]);
        _hold(idx, { "manual": on });
    }
    function setPct(idx, pct) {
        if (!available)
            return;
        const v = Math.max(0, Math.min(255, Math.round(pct / 100 * 255)));
        Quickshell.execDetached(["sh", Quickshell.shellPath("scripts/fans.sh"), "set", hwmon, String(idx), String(v)]);
        _hold(idx, { "pct": Math.round(v / 255 * 100), "manual": true });
    }

    // Temperature watchdog: force manual fans back to auto if the CPU gets hot.
    Connections {
        target: SystemStats
        function onCpuTempChanged() {
            const t = SystemStats.cpuTemp;
            if (!root.available || t <= 0)
                return;
            if (t >= root.safetyTemp && !root._safetyTripped) {
                const manual = root.fans.filter(f => f.manual);
                if (manual.length === 0)
                    return;
                root._safetyTripped = true;
                for (const f of manual)
                    root.setManual(f.idx, false);
                Quickshell.execDetached(["notify-send", "-u", "critical", "Fan safety", "CPU " + Math.round(t) + "°C — manual fans reverted to auto."]);
            } else if (t < root.safetyTemp - 6) {
                root._safetyTripped = false; // re-arm once it cools down
            }
        }
    }
}
