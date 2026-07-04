pragma Singleton

// Camera-import progress state + IPC entry point. The `camera-import` script
// drives this over Quickshell IPC while it runs:
//
//   qs ipc call cameraImport start    <total>      # begin (total<=0 => unknown)
//   qs ipc call cameraImport progress <done> <tot> # per-file tick
//   qs ipc call cameraImport finish   <imported>   # success, N filed to the NAS
//   qs ipc call cameraImport fail     <message>    # aborted with a reason
//
// CameraImportOsd.qml (one per screen) renders this. The IPC handler lives here
// in the singleton — not in the per-screen window — so it's registered exactly
// once regardless of how many monitors are connected (a duplicate target would
// clash). Auto-loads at launch because shell.qml references it.
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // "idle" | "running" | "done" | "error"
    property string phase: "idle"
    // Which half of a running import we're in: "download" (camera → staging) or
    // "filing" (staging → NAS). Drives the OSD glyph; counters reset between them.
    property string stage: ""
    property int total: 0
    property int done: 0
    property string message: ""

    readonly property bool indeterminate: total <= 0
    readonly property real fraction: total > 0 ? Math.min(1, done / total) : 0

    IpcHandler {
        target: "cameraImport"

        function start(total: int): string {
            root.stage = "download";
            root.total = total;
            root.done = 0;
            root.message = "";
            root.phase = "running";
            return "ok";
        }
        // Second phase: hand over to the staging → NAS copy, with a fresh count.
        function filing(total: int): string {
            root.stage = "filing";
            root.total = total;
            root.done = 0;
            root.phase = "running";
            return "ok";
        }
        function progress(done: int, total: int): string {
            if (total > 0)
                root.total = total;
            root.done = done;
            root.phase = "running";
            return "ok";
        }
        function finish(imported: int): string {
            root.done = imported;
            if (imported > root.total)
                root.total = imported;
            root.message = imported + (imported === 1 ? " photo" : " photos");
            root.phase = "done";
            return "ok";
        }
        function fail(message: string): string {
            root.message = message;
            root.phase = "error";
            return "ok";
        }
    }
}
