pragma Singleton

// Fan monitoring + control via the Nuvoton nct6799 hwmon (ROG STRIX X670E-I).
// Reads RPM/PWM/mode; writes pwmN_enable (1 = manual; otherwise restores the
// fan's ORIGINAL auto mode captured before we touched it) and pwmN (0-255).
// Writing needs the pwm* sysfs group-writable (a NixOS udev rule handles that);
// without it, writes no-op. The hwmon index isn't stable across boots, so it's
// resolved by chip name.
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
    property bool active: false     // faster polling while the fan UI is shown
    property var _origEnable: ({})  // idx -> auto mode seen before we touched it
    property int safetyTemp: 85     // °C — revert manual fans to auto at/above this
    property bool _safetyTripped: false

    Process {
        running: true
        command: ["sh", "-c", "for d in /sys/class/hwmon/hwmon*; do [ \"$(cat $d/name 2>/dev/null)\" = nct6799 ] && echo $d && break; done"]
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
        command: root.hwmon === "" ? ["true"] : ["sh", "-c", "for p in \"$1\"/pwm[0-9]; do i=$(basename \"$p\" | tr -dc 0-9); printf '%s|%s|%s|%s\\n' \"$i\" \"$(cat \"$1/fan${i}_input\" 2>/dev/null)\" \"$(cat \"$p\" 2>/dev/null)\" \"$(cat \"${p}_enable\" 2>/dev/null)\"; done", "_", root.hwmon]
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
                    out.push({
                                "idx": idx,
                                "rpm": rpm,
                                "pct": isFinite(pw) ? Math.round(pw / 255 * 100) : 0,
                                "manual": en === 1
                            });
                }
                root.fans = out;
            }
        }
    }

    function _autoMode(idx) {
        return root._origEnable[idx] !== undefined ? root._origEnable[idx] : 5;
    }
    function setManual(idx, on) {
        if (!available)
            return;
        Quickshell.execDetached(["sh", "-c", 'echo "$1" > "$2/pwm${3}_enable"', "_", String(on ? 1 : root._autoMode(idx)), hwmon, String(idx)]);
        readProc.running = true;
    }
    function setPct(idx, pct) {
        if (!available)
            return;
        const v = Math.max(0, Math.min(255, Math.round(pct / 100 * 255)));
        Quickshell.execDetached(["sh", "-c", 'echo 1 > "$2/pwm${3}_enable"; echo "$1" > "$2/pwm${3}"', "_", String(v), hwmon, String(idx)]);
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
