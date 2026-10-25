pragma Singleton

// Clipboard history (cliphist; the store daemon runs from niri) plus persistent
// pins. cliphist has no pinning and rotates old entries out, so a pinned clip's
// content is decoded to its own file under $XDG_STATE_HOME/quickshell/clip-pins
// and indexed in index.json — surviving rotation and restarts.
//
// Entries share one shape so lists can mix them:
//   { uid, id, preview, isImage, mime, pinned, pinKey, file }
// History entries carry the cliphist `id`; pins carry `pinKey` + `file`.
//
// Pin identity: text pins match history by preview (a re-copied pinned text,
// which cliphist stores under a new id, stays deduped). Image previews are just
// "Image · WxH" — every same-size image would collide — so image pins match by
// the cliphist id they were pinned from (srcId).
//
// First run migrates the previous shell's pins from ~/.cache/quickshell/clip-pins.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string pinDir: Settings.stateDir + "/clip-pins"
    readonly property string legacyPinDir: Settings.legacyDir + "/clip-pins"
    readonly property string thumbDir: (Quickshell.env("XDG_CACHE_HOME") || (Settings.home + "/.cache")) + "/quickshell/clip-thumbs"

    property var history: [] // cliphist entries, newest first
    // Pin entries (newest first), derived from the stored index.
    readonly property var pins: store.pins.map(p => ({
                "uid": "p" + p.key,
                "pinKey": p.key,
                "preview": p.preview,
                "isImage": p.isImage,
                "mime": p.mime,
                "file": p.file,
                "pinned": true
            }))

    // ── History ──────────────────────────────────────────────────────────────
    function refresh() {
        listProc.running = true;
    }
    function copy(entry) {
        if (entry.pinKey !== undefined) {
            if (entry.mime)
                Quickshell.execDetached(["sh", "-c", 'wl-copy -t "$1" < "$2"', "_", entry.mime, entry.file]);
            else
                Quickshell.execDetached(["sh", "-c", 'wl-copy < "$1"', "_", entry.file]);
        } else {
            Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" | wl-copy', "_", String(entry.id)]);
        }
    }
    // Copy, then paste into the window that had focus before the popout took
    // the keyboard (niri's focused window is unaffected by layer surfaces).
    function paste(entry) {
        copy(entry);
        const w = Niri.windows.find(w => w.focused);
        const terminal = /^(kitty|foot|alacritty|wezterm|st|[Xx]?term.*)$/.test(w?.appId ?? "");
        Quickshell.execDetached(["sh", Quickshell.shellPath("scripts/clip-paste.sh"), terminal ? "terminal" : "app"]);
    }
    // Delete one entry: from cliphist's history (by id; `delete` reads list
    // lines, of which it only uses the id), or for a pin, unpin it.
    function remove(entry) {
        if (entry.pinKey !== undefined) {
            unpin(entry);
            return;
        }
        Quickshell.execDetached(["sh", "-c", 'printf "%s\\t\\n" "$1" | cliphist delete', "_", String(entry.id)]);
        history = history.filter(e => e.uid !== entry.uid);
    }
    // Wipes cliphist's history; pins are kept.
    function wipe() {
        Quickshell.execDetached(["cliphist", "wipe"]);
        history = [];
    }

    Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    const i = line.indexOf("\t");
                    if (i < 0)
                        continue;
                    const id = line.slice(0, i);
                    const raw = line.slice(i + 1);
                    const m = raw.match(/binary data .*?\b(png|jpe?g|gif|webp|bmp|tiff)\b\s+(\d+x\d+)/i);
                    const t = m ? m[1].toLowerCase() : "";
                    out.push({
                        "uid": "h" + id,
                        "id": id,
                        "preview": m ? "Image · " + m[2] : raw.replace(/\s+/g, " ").trim(),
                        "isImage": !!m,
                        "mime": m ? "image/" + (t === "jpg" ? "jpeg" : t) : "",
                        "pinned": false
                    });
                }
                root.history = out;
            }
        }
    }

    // ── Pins ─────────────────────────────────────────────────────────────────
    function _holds(p, e) {
        if (e.isImage)
            return p.isImage && p.srcId !== undefined && p.srcId === String(e.id);
        return !p.isImage && p.preview === e.preview;
    }
    function isPinned(entry) {
        return entry.pinKey !== undefined || store.pins.some(p => _holds(p, entry)); // raw index: has srcId
    }
    function pin(entry) {
        if (isPinned(entry))
            return;
        const key = store.nextKey;
        const file = pinDir + "/" + key + ".bin";
        // Values go in as positional args, never interpolated into the script.
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$2")" && cliphist decode "$1" > "$2"', "_", String(entry.id), file]);
        store.nextKey = key + 1;
        store.pins = [{
                "key": key,
                "srcId": String(entry.id),
                "preview": entry.preview,
                "isImage": !!entry.isImage,
                "mime": entry.mime || "",
                "file": file
            }, ...store.pins];
    }
    function unpin(entry) {
        const p = entry.pinKey !== undefined ? store.pins.find(x => x.key === entry.pinKey) : store.pins.find(x => _holds(x, entry));
        if (!p)
            return;
        Quickshell.execDetached(["rm", "-f", p.file]);
        store.pins = store.pins.filter(x => x.key !== p.key);
    }
    function togglePin(entry) {
        isPinned(entry) ? unpin(entry) : pin(entry);
    }

    // Image thumbnail for a history entry: decoded once into the cache and
    // reused; calls back with a file:// URL. Pins point at their stored file.
    function thumbnail(entry, callback) {
        if (entry.pinKey !== undefined) {
            callback("file://" + entry.file);
            return;
        }
        const proc = thumbProc.createObject(root, {
            "command": ["sh", "-c", 'mkdir -p "$1"; f="$1/$2"; [ -s "$f" ] || cliphist decode "$2" > "$f"; echo "$f"', "_", thumbDir, String(entry.id)]
        });
        proc.done.connect(path => {
            callback("file://" + path);
            proc.destroy();
        });
        proc.running = true;
    }
    Component {
        id: thumbProc
        Process {
            id: tp
            signal done(string path)
            stdout: StdioCollector {
                onStreamFinished: tp.done(text.trim())
            }
        }
    }

    // ── Persistence + migration ──────────────────────────────────────────────
    property bool _dirReady: false
    Process {
        running: true
        command: ["mkdir", "-p", root.pinDir]
        onExited: {
            root._dirReady = true;
            if (root._dirty)
                pinFile.writeAdapter();
        }
    }
    property bool _dirty: false
    Timer {
        id: saveTimer
        interval: 50
        onTriggered: {
            if (root._dirReady)
                pinFile.writeAdapter();
            else
                root._dirty = true;
        }
    }

    FileView {
        id: pinFile
        path: root.pinDir + "/index.json"
        blockLoading: true
        watchChanges: false
        printErrors: false
        atomicWrites: true
        // Deferred: calling writeAdapter() from inside adapterUpdated makes a
        // second assignment in the same tick get lost (Quickshell 0.3.2).
        onAdapterUpdated: saveTimer.restart()
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                root._migrate();
        }

        JsonAdapter {
            id: store
            property var pins: [] // [{ key, srcId?, preview, isImage, mime, file }]
            property int nextKey: 1
        }
    }

    FileView {
        id: legacyIndex
        path: root.legacyPinDir + "/index.json"
        blockLoading: true
        printErrors: false
    }
    function _migrate() {
        let old = [];
        try {
            old = JSON.parse(legacyIndex.text() || "{}").pins || [];
        } catch (e) {}
        if (old.length === 0)
            return;
        // Copy the pinned content over and repoint each pin at its new file.
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$2" && cp -n "$1"/*.bin "$2"/ 2>/dev/null', "_", legacyPinDir, pinDir]);
        store.pins = old.map(p => Object.assign({}, p, {
                    "file": pinDir + "/" + p.key + ".bin"
                }));
        store.nextKey = Math.max(0, ...old.map(p => p.key || 0)) + 1;
    }
}
