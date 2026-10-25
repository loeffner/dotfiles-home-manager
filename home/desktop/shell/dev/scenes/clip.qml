// Scene: clipboard pins on the throwaway home — pin a history entry, check that
// a different same-size image is NOT considered pinned, unpin, and verify the
// pinned file was written.
import QtQuick
import Quickshell
import qs.services

ShellRoot {
    Component.onCompleted: Clip.refresh()
    Timer {
        running: true
        interval: 800
        onTriggered: {
            const imgs = Clip.history.filter(e => e.isImage);
            const texts = Clip.history.filter(e => !e.isImage);
            console.log("TEST history=" + Clip.history.length + " images=" + imgs.length + " texts=" + texts.length + " pins=" + Clip.pins.length);
            if (texts.length > 0) {
                Clip.pin(texts[0]);
                console.log("TEST text pinned=" + Clip.isPinned(texts[0]) + " pins=" + Clip.pins.length);
            }
            if (imgs.length > 0) {
                Clip.pin(imgs[0]);
                const twin = { "id": "999999", "preview": imgs[0].preview, "isImage": true };
                console.log("TEST image pinned=" + Clip.isPinned(imgs[0]) + " same-size-other-image pinned=" + Clip.isPinned(twin));
            }
        }
    }
    Timer {
        running: true
        interval: 1400
        onTriggered: {
            const f = Clip.pins[0]?.file ?? "";
            Qt.callLater(() => {});
            console.log("TEST newest pin file=" + f.split("/").slice(-2).join("/"));
            const t = Clip.history.find(e => !e.isImage);
            if (t) {
                Clip.unpin(t);
                console.log("TEST after unpin text pinned=" + Clip.isPinned(t) + " pins=" + Clip.pins.length);
            }
            Qt.exit(0);
        }
    }
}
