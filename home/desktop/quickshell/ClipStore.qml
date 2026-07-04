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

    function isPinned(preview) {
        return root.pins.some(p => p.preview === preview);
    }

    function pin(id, preview, isImage, mime) {
        if (isPinned(preview))
            return;
        const key = root._nextKey++;
        const file = root.dir + "/" + key + ".bin";
        // Values go in as positional args, never interpolated into the script.
        Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" > "$2"', "_", String(id), file]);
        root.pins = [{
                    "key": key,
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
    function unpinByPreview(preview) {
        const p = root.pins.find(x => x.preview === preview);
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
