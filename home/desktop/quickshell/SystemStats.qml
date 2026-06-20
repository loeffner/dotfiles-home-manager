pragma Singleton

// Lightweight system metrics sourced straight from /proc (via FileView) and a
// `ps` call for the process list — no external daemon (DankMaterialShell uses its
// Go `dgop` binary; we stay dependency-free). Sampling is slow while idle and
// quickens while the popup is open (SystemStats.active, set by SystemMon).
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property real cpu: 0        // 0..1
    property real mem: 0        // 0..1
    property real memUsedGB: 0
    property real memTotalGB: 0
    property real netRx: 0      // bytes/sec, summed over non-loopback ifaces
    property real netTx: 0
    property var procs: []      // [{ pid, comm, cpu, mem }], top by CPU

    // Set true by the popup so we poll faster and only run `ps` when visible.
    property bool active: false

    property var _prevCpu: null
    property var _prevNet: null
    property real _prevT: 0

    Timer {
        interval: root.active ? 2000 : 6000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            statFile.reload();
            memFile.reload();
            netFile.reload();
            if (root.active)
                topProc.running = true;
        }
    }

    FileView {
        id: statFile
        path: "/proc/stat"
        watchChanges: false
        printErrors: false
        onLoaded: root._parseCpu(text())
    }
    FileView {
        id: memFile
        path: "/proc/meminfo"
        watchChanges: false
        printErrors: false
        onLoaded: root._parseMem(text())
    }
    FileView {
        id: netFile
        path: "/proc/net/dev"
        watchChanges: false
        printErrors: false
        onLoaded: root._parseNet(text())
    }

    function _parseCpu(t) {
        const line = t.split("\n").find(l => l.startsWith("cpu "));
        if (!line)
            return;
        const p = line.trim().split(/\s+/).slice(1).map(Number);
        // user nice system idle iowait irq softirq steal ...
        const idle = p[3] + (p[4] || 0);
        const total = p.reduce((a, b) => a + b, 0);
        if (root._prevCpu) {
            const dTotal = total - root._prevCpu.total;
            const dIdle = idle - root._prevCpu.idle;
            if (dTotal > 0)
                root.cpu = Math.max(0, Math.min(1, 1 - dIdle / dTotal));
        }
        root._prevCpu = { total, idle };
    }

    function _parseMem(t) {
        const get = k => {
            const m = t.match(new RegExp("^" + k + ":\\s+(\\d+)", "m"));
            return m ? Number(m[1]) : 0; // kB
        };
        const total = get("MemTotal");
        const avail = get("MemAvailable");
        if (total > 0) {
            root.mem = (total - avail) / total;
            root.memTotalGB = total / 1048576;
            root.memUsedGB = (total - avail) / 1048576;
        }
    }

    function _parseNet(t) {
        let rx = 0, tx = 0;
        for (const line of t.split("\n")) {
            const m = line.match(/^\s*([\w-]+):\s*(.*)$/);
            if (!m || m[1] === "lo")
                continue;
            const f = m[2].trim().split(/\s+/).map(Number);
            rx += f[0];  // bytes received
            tx += f[8];  // bytes transmitted
        }
        const now = Date.now() / 1000;
        if (root._prevNet && root._prevT > 0) {
            const dt = now - root._prevT;
            if (dt > 0) {
                root.netRx = Math.max(0, (rx - root._prevNet.rx) / dt);
                root.netTx = Math.max(0, (tx - root._prevNet.tx) / dt);
            }
        }
        root._prevNet = { rx, tx };
        root._prevT = now;
    }

    Process {
        id: topProc
        command: ["sh", "-c", "ps -eo pid=,comm=,pcpu=,pmem= --sort=-pcpu | head -n 8"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.trim().split("\n")) {
                    const m = line.trim().match(/^(\d+)\s+(.+?)\s+([\d.]+)\s+([\d.]+)$/);
                    if (m)
                        out.push({ pid: m[1], comm: m[2], cpu: Number(m[3]), mem: Number(m[4]) });
                }
                root.procs = out;
            }
        }
    }

    // Human-readable byte rate, e.g. 1.2M / 340K / 12B.
    function fmtRate(b) {
        if (b >= 1048576)
            return (b / 1048576).toFixed(1) + "M";
        if (b >= 1024)
            return (b / 1024).toFixed(0) + "K";
        return Math.round(b) + "B";
    }
}
