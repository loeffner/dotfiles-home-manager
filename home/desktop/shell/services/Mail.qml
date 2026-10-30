pragma Singleton

// Mail — the inbox for the mail panel, as conversations, read from notmuch.
// home/mail.nix syncs the Outlook account into ~/Maildir with mbsync every few
// minutes; the notmuch post-new hook then calls `qs ipc call mail refresh`.
// Changes (read, star, archive, delete) apply to the list at once and go to
// notmuch (tags; archive/delete move the files, scripts/mail.sh); a sync a few
// seconds later pushes them to the server.
//
// A thread (conversation) in `threads`: { id (its first message's id), subject,
// from (who's in it, "me" for you), sender (latest author), snippet, date (ms,
// latest message), count, unread, unreadCount, starred, attachments: [name],
// inbox: [ids in the inbox], all: [ids] }. Conversations load on demand into
// `conversations` (thread id -> [message]); a message: { id, from, address,
// mine, to, date, unread, starred, attachments: [{ name, part }], text }
// (part: the MIME part number, for saveAttachment()).
//
// Under the dev harness (QS_MAIL_MOCK=1, set by dev/run unless --real-home) it
// serves dev/mail-mock.json and changes stay in memory.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property bool mock: Quickshell.env("QS_MAIL_MOCK") === "1"
    readonly property string query: "folder:outlook/Inbox"
    readonly property int limit: 100 // conversations

    property var threads: []
    property int unreadCount: 0 // unread messages in the whole inbox
    property var conversations: ({})
    property bool available: false // notmuch answered (mail is set up)
    property bool syncing: false
    property real lastSync: 0

    function find(id) {
        return threads.find(t => t.id === id) ?? null;
    }
    function _patch(id, fields) {
        threads = threads.map(t => t.id === id ? Object.assign({}, t, fields) : t);
    }
    // Apply the same change to a loaded conversation's messages.
    function _patchConversation(id, fn) {
        const c = conversations[id];
        if (!c)
            return;
        const all = Object.assign({}, conversations);
        all[id] = c.map(fn);
        conversations = all;
    }
    function _query(ids) {
        return ids.map(id => 'id:"' + id.replace(/"/g, '""') + '"').join(" or ");
    }
    function _script(args) {
        return ["sh", Quickshell.shellPath("scripts/mail.sh")].concat(args);
    }
    // Run a change in notmuch, then push it to the server shortly after.
    function _change(cmd) {
        if (mock)
            return;
        Quickshell.execDetached(cmd);
        pushTimer.restart();
    }

    function setRead(id, read) {
        const t = find(id);
        if (!t || t.unread !== read)
            return;
        // Read: every message. Unread: just the latest one received, like
        // webmail (`inbox` is oldest first).
        const n = read ? t.unreadCount : 1;
        const last = t.inbox[t.inbox.length - 1];
        _patch(id, { "unread": !read, "unreadCount": read ? 0 : 1 });
        unreadCount += read ? -n : n;
        _patchConversation(id, m => Object.assign({}, m, { "unread": !read && m.id === last }));
        _change(["notmuch", "tag", read ? "-unread" : "+unread", "--", _query(read ? t.all : [last])]);
    }
    // Starred if any message is; starring flags the latest message.
    function toggleStar(id) {
        const t = find(id);
        if (!t)
            return;
        _patch(id, { "starred": !t.starred });
        const ids = t.starred ? t.all : [t.inbox[t.inbox.length - 1]];
        _patchConversation(id, m => Object.assign({}, m, { "starred": !t.starred && ids.includes(m.id) }));
        _change(["notmuch", "tag", t.starred ? "-flagged" : "+flagged", "--", _query(ids)]);
    }
    // Archive / delete move the conversation's inbox mail into that folder;
    // delete goes to the trash folder (recoverable, like webmail).
    function archive(id) {
        _moveOut(id, "Archive");
    }
    function trash(id) {
        _moveOut(id, "Deleted");
    }
    function _moveOut(id, folder) {
        const t = find(id);
        if (!t)
            return;
        threads = threads.filter(x => x.id !== id);
        unreadCount -= t.unreadCount;
        _change(_script(["move", folder].concat(t.inbox)));
    }

    // Re-read the index (cheap; no network).
    function reload() {
        if (mock)
            return;
        if (listProc.running)
            _reloadAgain = true;
        else
            listProc.running = true;
    }
    // Fetch from the server now, then re-read.
    function sync() {
        syncing = true;
        if (mock)
            mockSync.restart();
        else
            syncProc.running = true;
    }
    // Load (or refresh) a conversation into `conversations`.
    function loadConversation(id) {
        if (mock) {
            _setConversation(id, _mockConversations[id] ?? []);
        } else if (threadProc.running) {
            _nextThread = id;
        } else {
            threadProc.forId = id;
            threadProc.running = true;
        }
    }
    function _setConversation(id, msgs) {
        const all = Object.assign({}, conversations);
        all[id] = msgs;
        conversations = all;
    }
    // Ask where to save an attachment ({ name, part } of a conversation message)
    // with a file dialog. Mail never opens one by itself: it may be from a stranger.
    function saveAttachment(messageId, attachment) {
        if (mock) {
            console.log("mail: save attachment " + attachment.name);
            return;
        }
        Quickshell.execDetached(_script(["save", messageId, String(attachment.part), attachment.name]));
    }
    // Outlook on the web, for sending and whatever else the panel can't do.
    function openWebmail() {
        Quickshell.execDetached(["xdg-open", "https://outlook.live.com/mail/"]);
    }

    property bool _reloadAgain: false
    property string _nextThread: ""

    Process {
        id: listProc
        command: root._script(["list", root.query, String(root.limit)])
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const r = JSON.parse(text);
                    root.threads = r.threads;
                    root.unreadCount = r.unread;
                    root.available = true;
                    root.lastSync = Date.now();
                } catch (e) {
                    root.available = false;
                }
            }
        }
        onExited: if (root._reloadAgain) {
            root._reloadAgain = false;
            running = true;
        }
    }

    Process {
        id: threadProc
        property string forId: ""
        command: root._script(["thread", forId])
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root._setConversation(threadProc.forId, JSON.parse(text));
                } catch (e) {
                    root._setConversation(threadProc.forId, []);
                }
            }
        }
        onExited: if (root._nextThread !== "") {
            forId = root._nextThread;
            root._nextThread = "";
            running = true;
        }
    }

    // A oneshot unit: `start` returns once mbsync and `notmuch new` are done.
    Process {
        id: syncProc
        command: ["systemctl", "--user", "start", "mbsync.service"]
        onExited: {
            root.syncing = false;
            root.reload();
        }
    }
    Timer {
        id: pushTimer
        interval: 4000
        onTriggered: Quickshell.execDetached(["systemctl", "--user", "start", "--no-block", "mbsync.service"])
    }

    // notmuch's post-new hook (home/mail.nix).
    IpcHandler {
        target: "mail"
        function refresh(): string {
            root.reload();
            return "ok";
        }
    }

    // ── Dev mock ─────────────────────────────────────────────────────────────
    property var _mockConversations: ({})

    FileView {
        id: mockFile
        path: root.mock ? Quickshell.shellPath("dev/mail-mock.json") : ""
        blockLoading: true
    }
    Timer {
        id: mockSync
        interval: 900
        onTriggered: {
            root.syncing = false;
            root.lastSync = Date.now();
        }
    }

    Component.onCompleted: {
        if (!mock) {
            reload();
            return;
        }
        // Build what scripts/mail.sh would: threads + their conversations.
        const now = Date.now();
        const convs = {};
        threads = JSON.parse(mockFile.text()).threads.map(t => {
            const msgs = t.messages.map(m => Object.assign({
                    "address": "",
                    "mine": false,
                    "to": "",
                    "unread": false,
                    "starred": false,
                    "attachments": []
                }, m, {
                    "date": now - m.ago * 60000,
                    "text": m.body,
                    "attachments": (m.attachments ?? []).map((name, i) => ({
                                "name": name,
                                "part": i + 2
                            }))
                }));
            const last = msgs[msgs.length - 1];
            const people = [];
            for (const m of msgs) {
                const n = m.mine ? "me" : m.from;
                if (!people.includes(n))
                    people.push(n);
            }
            convs[msgs[0].id] = msgs;
            return {
                "id": msgs[0].id,
                "subject": t.subject,
                "from": people.join(", "),
                "sender": last.from,
                "snippet": last.body.replace(/\s+/g, " ").slice(0, 180),
                "date": last.date,
                "count": msgs.length,
                "unreadCount": msgs.filter(m => m.unread).length,
                "unread": msgs.some(m => m.unread),
                "starred": msgs.some(m => m.starred),
                "attachments": msgs.reduce((a, m) => a.concat(m.attachments.map(x => x.name)), []),
                "inbox": msgs.filter(m => !m.mine).map(m => m.id),
                "all": msgs.map(m => m.id)
            };
        });
        _mockConversations = convs;
        unreadCount = threads.reduce((n, t) => n + t.unreadCount, 0);
        available = true;
        lastSync = now;
    }
}
