pragma Singleton

// System metrics via `dgop` — the same helper DankMaterialShell uses. This gives
// accurate INSTANTANEOUS CPU, PSS-based memory (used = total-free-buffers-cache-
// reclaimable+shared, matching htop), and per-process cpu/mem already expressed as
// % of the whole system, so the process numbers sum to the gauges. GPU usage/temp
// come from nvidia-smi / amdgpu sysfs (dgop doesn't read them on this hardware).
// Static system info is read once. Polling quickens while the panel is open
// (SystemStats.active, set by SysPill).
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property real cpu: 0        // 0..1
    property real cpuTemp: 0    // °C
    property string _cpuCursor: "" // dgop delta cursor for accurate CPU %
    property real mem: 0        // 0..1
    property real memUsedGB: 0
    property real memTotalGB: 0
    property real swap: 0       // 0..1
    property real swapUsedGB: 0
    property real swapTotalGB: 0

    property real _gpuAmdTemp: 0
    property real _gpuAmdUse: 0
    property real _gpuNvTemp: 0
    property real _gpuNvUse: 0
    readonly property real gpuTemp: _gpuNvTemp > 0 ? _gpuNvTemp : _gpuAmdTemp  // °C
    readonly property real gpuUsage: _gpuNvTemp > 0 ? _gpuNvUse : _gpuAmdUse   // 0..1
    readonly property bool gpuAvailable: gpuTemp > 0 || gpuUsage > 0

    property var procs: []       // top 8 by cpu (legacy)
    property var procsFull: []   // [{ pid, user, comm, cpu, mem }]; cpu/mem = % of total

    property string hostname: ""
    property string distro: ""
    property string kernel: ""
    property string cpuModel: ""
    property string gpuName: ""
    property real uptime: 0      // seconds

    readonly property string user: Quickshell.env("USER") || ""

    // Set true by the panel so we poll faster and only list processes when open.
    property bool active: false

    function killProcess(pid) {
        Quickshell.execDetached(["kill", String(pid)]);
    }

    function fmtUptime(s) {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        if (d > 0) return d + "d " + h + "h";
        if (h > 0) return h + "h " + m + "m";
        return m + "m";
    }

    Timer {
        interval: root.active ? 2000 : 6000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            cpuProc.running = true;
            uptimeFile.reload();
            if (root.active) {
                memProc.running = true;
                procProc.running = true;
                gpuProc.running = true;
            }
        }
    }

    // CPU usage + temperature. Accurate usage needs dgop's delta cursor (the
    // previous call's cursor), otherwise a single `meta`/`cpu` call reports a
    // noisy/near-zero window — this is what made the total spike.
    Process {
        id: cpuProc
        command: root._cpuCursor !== "" ? ["dgop", "cpu", "--json", "--cursor", root._cpuCursor] : ["dgop", "cpu", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    if (d.cursor) {
                        root._cpuCursor = d.cursor;
                        root.cpu = Math.max(0, Math.min(1, (d.usage || 0) / 100));
                    }
                    if (d.temperature > 0)
                        root.cpuTemp = d.temperature;
                } catch (e) {}
            }
        }
    }

    // Memory (only while the panel is open). dgop's usedPercent matches htop.
    Process {
        id: memProc
        command: ["dgop", "memory", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.mem = Math.max(0, Math.min(1, (d.usedPercent || 0) / 100));
                    root.memUsedGB = (d.used || 0) / 1048576;
                    root.memTotalGB = (d.total || 0) / 1048576;
                    const st = d.swaptotal || 0, sf = d.swapfree || 0;
                    root.swapTotalGB = st / 1048576;
                    root.swapUsedGB = (st - sf) / 1048576;
                    root.swap = st > 0 ? (st - sf) / st : 0;
                } catch (e) {}
            }
        }
    }

    // Process list (only while the panel is open). dgop's cpu/memoryPercent are
    // already % of the whole system.
    Process {
        id: procProc
        command: ["dgop", "processes", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    const out = (d.processes || []).map(p => ({
                                "pid": String(p.pid),
                                "user": p.username || "",
                                "comm": p.command || "",
                                "cpu": p.cpu || 0,
                                "mem": p.memoryPercent || 0
                            }));
                    out.sort((a, b) => b.cpu - a.cpu);
                    root.procsFull = out;
                    root.procs = out.slice(0, 8);
                } catch (e) {}
            }
        }
    }

    // GPU usage + temperature: NVIDIA via nvidia-smi; amdgpu busy%/edge temp from
    // sysfs as the fallback when the discrete GPU is asleep/absent.
    Process {
        id: gpuProc
        command: ["sh", "-c", "echo \"nv|$(nvidia-smi --query-gpu=temperature.gpu,utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1)\"; echo \"amdbusy|$(cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | head -1)\"; echo \"amdtemp|$(for h in /sys/class/hwmon/hwmon*; do [ \"$(cat $h/name 2>/dev/null)\" = amdgpu ] && for f in \"$h\"/temp*_input; do [ \"$(cat ${f%_input}_label 2>/dev/null)\" = edge ] && cat \"$f\"; done; done | head -1)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.trim().split("\n")) {
                    const i = line.indexOf("|");
                    if (i < 0)
                        continue;
                    const k = line.slice(0, i), v = line.slice(i + 1).trim();
                    if (k === "nv") {
                        const f = v.split(",").map(x => Number(x.trim()));
                        root._gpuNvTemp = (isFinite(f[0]) && f[0] > 0) ? f[0] : 0;
                        root._gpuNvUse = isFinite(f[1]) ? Math.max(0, Math.min(1, f[1] / 100)) : 0;
                    } else if (k === "amdbusy") {
                        const b = Number(v);
                        root._gpuAmdUse = isFinite(b) ? Math.max(0, Math.min(1, b / 100)) : 0;
                    } else if (k === "amdtemp") {
                        const t = Number(v) / 1000;
                        root._gpuAmdTemp = isFinite(t) && t > 0 ? t : 0;
                    }
                }
            }
        }
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        watchChanges: false
        printErrors: false
        onLoaded: {
            const s = Number(text().trim().split(/\s+/)[0]);
            if (isFinite(s))
                root.uptime = s;
        }
    }

    // Static system info — read once at startup.
    Process {
        running: true
        command: ["sh", "-c", "echo \"host|$(uname -n)\"; echo \"kernel|$(uname -r)\"; ( . /etc/os-release 2>/dev/null; echo \"os|$PRETTY_NAME\" ); echo \"cpu|$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')\"; g=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1); [ -z \"$g\" ] && g=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | head -1 | sed 's/.*: //'); echo \"gpu|$g\""]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.trim().split("\n")) {
                    const i = line.indexOf("|");
                    if (i < 0)
                        continue;
                    const k = line.slice(0, i), v = line.slice(i + 1).trim();
                    if (k === "host") root.hostname = v;
                    else if (k === "kernel") root.kernel = v;
                    else if (k === "os") root.distro = v;
                    else if (k === "cpu") root.cpuModel = v;
                    else if (k === "gpu") root.gpuName = v;
                }
            }
        }
    }
}
