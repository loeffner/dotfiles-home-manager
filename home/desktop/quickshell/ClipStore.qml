pragma Singleton

// Persistent clipboard pins. cliphist has no native pinning and rotates old
// entries out, so a pinned clip's content is decoded to its own file under
// ~/.cache/quickshell/clip-pins and indexed in index.json — surviving history
// rotation and restarts. Copying a pin writes that file back to the clipboard
// (with its MIME type for images).
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string dir: (Quickshell.env("HOME") || "") + "/.cache/quickshell/clip-pins"
    property var pins: [] // [{ key, preview, isImage, mime, file }]
    property int _nextKey: 1

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", root.dir]);
        store.reload();
    }

    FileView {
        id: store
        path: root.dir + "/index.json"
        watchChanges: false
        printErrors: false
        atomicWrites: true
        onLoaded: {
            try {
                const d = JSON.parse(text());
                root.pins = d.pins || [];
                let mx = 0;
                for (const p of root.pins)
                    mx = Math.max(mx, p.key || 0);
                root._nextKey = mx + 1;
            } catch (e) {}
        }
    }
    function _save() {
        store.setText(JSON.stringify({
            "pins": root.pins
        }));
    }

    // Does pin p hold cliphist entry e? Text matches by preview (so a re-copied
    // pinned text, which cliphist stores under a new id, stays deduped). Image
    // previews are just "Image · WxH" — every same-size image would collide — so
    // images match by the cliphist id they were pinned from (srcId).
    function _holds(p, e) {
        if (e.isImage)
            return p.isImage && p.srcId !== undefined && p.srcId === String(e.id);
        return !p.isImage && p.preview === e.preview;
    }
    function isPinned(e) {
        return root.pins.some(p => _holds(p, e));
    }

    function pin(e) {
        if (isPinned(e))
            return;
        const id = e.id, preview = e.preview, isImage = e.isImage, mime = e.mime;
        const key = root._nextKey++;
        const file = root.dir + "/" + key + ".bin";
        // Values go in as positional args, never interpolated into the script.
        Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" > "$2"', "_", String(id), file]);
        root.pins = [{
                    "key": key,
                    "srcId": String(id),
                    "preview": preview,
                    "isImage": !!isImage,
                    "mime": mime || "",
                    "file": file
                }, ...root.pins];
        _save();
    }
    function unpin(key) {
        const p = root.pins.find(x => x.key === key);
        if (p)
            Quickshell.execDetached(["rm", "-f", p.file]);
        root.pins = root.pins.filter(x => x.key !== key);
        _save();
    }
    function unpinEntry(e) {
        const p = root.pins.find(x => _holds(x, e));
        if (p)
            unpin(p.key);
    }
    function copyPin(p) {
        if (p.mime)
            Quickshell.execDetached(["sh", "-c", 'wl-copy -t "$1" < "$2"', "_", p.mime, p.file]);
        else
            Quickshell.execDetached(["sh", "-c", 'wl-copy < "$1"', "_", p.file]);
    }
}
