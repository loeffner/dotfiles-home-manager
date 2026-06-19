pragma Singleton

// Notification daemon. `list` is the live tracked set (drives toasts).
// `history` is a persistent log of every notification that arrived — plain
// JS objects so they survive after the notification is dismissed. The bell
// panel shows history; DND suppresses toasts but still records to history.
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    property bool dnd: false
    readonly property var list: server.trackedNotifications
    property var history: [] // [{summary, body, appName, urgency, time}]

    NotificationServer {
        id: server
        keepOnReload: false
        bodySupported: true
        actionsSupported: true
        imageSupported: true
        bodyMarkupSupported: true
        onNotification: n => {
            // Record to history first (captures the text before any dismiss).
            root.history = [{
                    summary: n.summary ?? "",
                    body: n.body ?? "",
                    appName: n.appName ?? "",
                    urgency: n.urgency,
                    time: new Date()
                }, ...root.history].slice(0, 50); // cap at 50 entries
            // Track (→ toast) unless DND is on.
            n.tracked = !root.dnd;
        }
    }

    function dismissAll() {
        const items = server.trackedNotifications.values.slice();
        for (const n of items)
            n.dismiss();
    }

    function clearHistory() {
        history = [];
    }
}
