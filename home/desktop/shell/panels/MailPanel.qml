// Mail panel ("mail"): the inbox as conversations, grouped by day, filterable
// (All / Unread / Starred) and searchable. A row shows who's in the
// conversation, how many messages it has and the latest one. Clicking it slides
// the reader in (the panel widens for it) and marks it read: the conversation
// stacked oldest first, earlier messages collapsed to a line (click to expand),
// the latest and the unread ones open, quoted text folded behind a "•••"
// toggle. Back arrow, Escape or Backspace go back. Rows show quick actions
// (star, read/unread, archive, delete) on hover; delete moves to the trash
// folder, like webmail. The header syncs now, or opens Outlook on the web (for
// sending and anything else the panel can't do).
//
// Keys: Tab/⇧Tab switch All/Unread/Starred, j/k or ↑/↓ move, Enter or Space
// opens, / searches, r syncs; e archives and d (or
// Delete) deletes the selected conversation; in the reader j/k scroll, s stars,
// u marks unread, e archives, d deletes. ? shows them all (`shortcuts` below).
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.island
import qs.services

IslandPanel {
    id: root
    panelId: "mail"
    searchField: search
    panelWidth: readingId !== "" ? 600 : 440

    property int filter: 0 // 0 All, 1 Unread, 2 Starred
    property string readingId: ""
    property bool kbNav: false // highlight the current row only once keys move it
    readonly property var reading: readingId !== "" ? Mail.find(readingId) : null
    property int openedUnread: 0 // unread messages when the conversation was opened

    // The shortcut sheet (?, IslandPanel); keep in step with keys' Keys.onPressed.
    shortcutSection: readingId !== "" ? 1 : 0
    shortcuts: [
        {
            "title": "Inbox",
            "keys": [
                [["Tab", "⇧Tab"], "All / Unread / Starred"],
                [["j", "k"], "Move down / up"],
                [["Enter", "Space"], "Open conversation"],
                [["e"], "Archive selected"],
                [["d", "Del"], "Delete selected"],
                [["r"], "Sync now"]
            ]
        },
        {
            "title": "Conversation",
            "keys": [
                [["j", "k"], "Scroll"],
                [["s"], "Star"],
                [["u"], "Mark unread"],
                [["e"], "Archive"],
                [["d", "Del"], "Delete"],
                [["⌫", "h"], "Back to inbox"],
                [["Esc"], "Back"]
            ]
        }
    ]

    onOpened: {
        readingId = "";
        help = false;
        kbNav = false;
        search.clear();
        list.currentIndex = 0;
        list.positionViewAtBeginning();
        Mail.reload();
        Qt.callLater(() => keys.forceActiveFocus());
    }

    readonly property var entries: {
        const q = search.text.toLowerCase();
        return Mail.threads.filter(t => (filter === 0 || (filter === 1 ? t.unread : t.starred)) && (!q || (t.from + " " + t.subject + " " + t.snippet).toLowerCase().indexOf(q) >= 0)).sort((a, b) => b.date - a.date);
    }

    function openThread(id) {
        openedUnread = Mail.find(id)?.unreadCount ?? 0;
        readingId = id;
        Mail.setRead(id, true);
        Mail.loadConversation(id);
        reader.contentY = 0;
    }
    function back() {
        readingId = "";
        keys.forceActiveFocus();
    }
    // Archive, or delete (into the trash folder); leaves the reader if it
    // showed that conversation.
    function archive(id) {
        if (id === readingId)
            back();
        Mail.archive(id);
    }
    function trash(id) {
        if (id === readingId)
            back();
        Mail.trash(id);
    }

    // ── Formatting ───────────────────────────────────────────────────────────
    function dayGroup(ms) {
        const now = new Date();
        const start = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
        if (ms >= start)
            return "Today";
        if (ms >= start - 86400000)
            return "Yesterday";
        if (ms >= start - 6 * 86400000)
            return "This week";
        return "Earlier";
    }
    function shortTime(ms) {
        const g = dayGroup(ms), d = new Date(ms);
        if (g === "Today")
            return Qt.formatTime(d, "hh:mm");
        if (g === "Yesterday")
            return "Yesterday";
        if (g === "This week")
            return Qt.formatDate(d, "ddd");
        return Qt.formatDate(d, "d MMM");
    }
    function longTime(ms) {
        return Qt.formatDateTime(new Date(ms), "ddd d MMM yyyy, hh:mm");
    }
    function avatarColor(name) {
        const keys = Theme.accentOrder.filter(k => k !== "ivory");
        let h = 0;
        for (let i = 0; i < name.length; i++)
            h = (h * 31 + name.charCodeAt(i)) >>> 0;
        return Theme.accents[keys[h % keys.length]];
    }
    // Plain-text body → rich text: escaped, links clickable, quoted lines muted.
    function bodyHtml(text) {
        const esc = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        const link = s => s.replace(/(https?:\/\/[^\s<]+)/g, `<a href="$1" style="color:${Theme.primary};text-decoration:none">$1</a>`);
        return text.split("\n").map(l => {
            const h = link(esc(l));
            return /^\s*>/.test(l) ? `<span style="color:${Theme.surfaceVariantText}">${h}</span>` : h;
        }).join("<br>");
    }
    // Split a reply into what's new and the quoted history below it, at the
    // first attribution ("Am … schrieb …:", "On … wrote:", possibly wrapped),
    // forwarded/Outlook header block, or a ">" run that lasts to the end.
    function splitQuote(text) {
        const lines = text.replace(/\s+$/, "").split("\n");
        const at = i => lines[i] ?? "";
        const attribution = i => /^\s*(Am|On)\s/.test(at(i)) && [at(i), at(i) + " " + at(i + 1), at(i) + " " + at(i + 1) + " " + at(i + 2)].some(s => s.length < 300 && /\b(schrieb|wrote)\b[^:]*:\s*$/.test(s));
        const headerBlock = i => /^\s*-{3,}\s*(Original Message|Ursprüngliche Nachricht|Forwarded message|Weitergeleitete Nachricht)/i.test(at(i))
            || (/^\s*(Von|From):\s/.test(at(i)) && /^\s*(Gesendet|Sent|Datum|Date):/m.test(at(i + 1) + "\n" + at(i + 2)))
            || (/^\s*(-{5,}|_{5,})\s*$/.test(at(i)) && /^\s*(Von|From):/m.test(at(i + 1) + "\n" + at(i + 2)));
        const quoteRun = i => /^\s*>/.test(at(i)) && lines.slice(i).every(l => /^\s*(>|$)/.test(l));
        for (let i = 1; i < lines.length; i++) {
            if (attribution(i) || headerBlock(i) || quoteRun(i))
                // (minus a dashed/underscored divider left above the quote)
                return { "main": lines.slice(0, i).join("\n").replace(/(\n\s*([-_]{5,})?\s*)+$/, ""), "quoted": lines.slice(i).join("\n") };
        }
        return { "main": lines.join("\n"), "quoted": "" };
    }

    component Avatar: Rectangle {
        property string name: ""
        property real size: 34
        implicitWidth: size
        implicitHeight: size
        radius: size / 2
        color: root.avatarColor(name)
        MText {
            anchors.centerIn: parent
            text: parent.name.charAt(0).toUpperCase()
            color: Theme.contrastText(parent.color)
            font.bold: true
            sizeDelta: parent.size > 36 ? 3 : parent.size < 30 ? 0 : 1
        }
    }

    // An attachment of one message: click to unpack and open it in its default
    // app. Hover swaps the file-type icon for an open icon; a click shows
    // "Opening…" briefly while the app starts.
    component AttachmentChip: Rectangle {
        id: chip
        required property var modelData // { name, part }
        required property string messageId
        readonly property bool hovered: chipHover.hovered
        property bool opening: false
        implicitHeight: 28
        implicitWidth: chipRow.implicitWidth + 18
        radius: Theme.radiusS
        color: hovered ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
        Behavior on color { ColorAnimation { duration: 110 } }
        HoverHandler {
            id: chipHover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            onTapped: {
                Mail.openAttachment(chip.messageId, chip.modelData);
                chip.opening = true;
                openingTimer.restart();
            }
        }
        Timer {
            id: openingTimer
            interval: 1500
            onTriggered: chip.opening = false
        }
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 6
            MIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.hovered || chip.opening ? "open_in_new" : /\.pdf$/i.test(chip.modelData.name) ? "picture_as_pdf" : /\.(jpe?g|png|gif|webp|heic)$/i.test(chip.modelData.name) ? "image" : "description"
                size: 15
                color: Theme.primary
            }
            MText {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.opening ? "Opening…" : chip.modelData.name
                sizeDelta: -1
            }
        }
    }

    // ── Header ───────────────────────────────────────────────────────────────
    PanelHeader {
        icon: "mail"
        title: "Inbox"
        Rectangle {
            visible: Mail.unreadCount > 0
            implicitHeight: 22
            implicitWidth: newLabel.implicitWidth + 16
            radius: 11
            color: Theme.primary
            MText {
                id: newLabel
                anchors.centerIn: parent
                text: Mail.unreadCount + " new"
                sizeDelta: -1
                font.bold: true
                color: Theme.primaryText
            }
        }
        MIconButton {
            icon: "refresh"
            raised: true
            onClicked: Mail.sync()
            RotationAnimator on rotation {
                running: Mail.syncing
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
                onRunningChanged: if (!running) parent.rotation = 0
            }
        }
        MIconButton {
            icon: "open_in_new"
            raised: true
            onClicked: {
                Mail.openWebmail();
                root.close();
            }
        }
    }

    // ── List ⇄ reader ────────────────────────────────────────────────────────
    // The reader always gets the full height; the list only what it needs, up
    // to the same cap (an empty filter or a short inbox gives a compact panel;
    // the island animates the change).
    readonly property int maxBodyHeight: 560
    readonly property int rowHeight: 64
    // Day header above the first row of each group (less room at the very top).
    function headerHeight(index) {
        return index === 0 ? 22 : 32;
    }

    Item {
        id: keys
        Layout.fillWidth: true
        Layout.preferredHeight: root.readingId !== "" ? root.maxBodyHeight : Math.min(root.maxBodyHeight, listPage.naturalHeight)
        clip: true
        focus: true

        Keys.onPressed: e => {
            // ? toggles the shortcut sheet; while it's up, any key closes it.
            if (e.key === Qt.Key_Question || e.text === "?" || root.help) {
                root.help = !root.help && (e.key === Qt.Key_Question || e.text === "?");
                e.accepted = true;
                return;
            }
            const reading = root.readingId !== "";
            if (reading) {
                switch (e.key) {
                case Qt.Key_Backspace:
                case Qt.Key_Left:
                case Qt.Key_H:
                    root.back();
                    break;
                case Qt.Key_Slash: // search the inbox: back to the list, into its search
                    root.back();
                    search.focusInput();
                    break;
                case Qt.Key_J:
                case Qt.Key_Down:
                    reader.flick(0, -900);
                    break;
                case Qt.Key_K:
                case Qt.Key_Up:
                    reader.flick(0, 900);
                    break;
                case Qt.Key_S:
                    Mail.toggleStar(root.readingId);
                    break;
                case Qt.Key_U:
                    Mail.setRead(root.readingId, false);
                    root.back();
                    break;
                case Qt.Key_E:
                    root.archive(root.readingId);
                    break;
                case Qt.Key_D:
                case Qt.Key_Delete:
                    root.trash(root.readingId);
                    break;
                default:
                    return;
                }
            } else {
                switch (e.key) {
                case Qt.Key_J:
                case Qt.Key_Down:
                    root.kbNav = true;
                    list.incrementCurrentIndex();
                    break;
                case Qt.Key_K:
                case Qt.Key_Up:
                    root.kbNav = true;
                    list.decrementCurrentIndex();
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                case Qt.Key_Space:
                    if (root.entries[list.currentIndex])
                        root.openThread(root.entries[list.currentIndex].id);
                    break;
                case Qt.Key_Slash:
                    search.focusInput();
                    break;
                case Qt.Key_Tab:
                case Qt.Key_Backtab:
                    root.filter = (root.filter + 3 + root.tabStep(e)) % 3;
                    list.currentIndex = 0;
                    break;
                case Qt.Key_R:
                    Mail.sync();
                    break;
                // Only on a row the keys selected (highlighted), never blind.
                case Qt.Key_E:
                case Qt.Key_D:
                case Qt.Key_Delete:
                    if (root.kbNav && root.entries[list.currentIndex]) {
                        const id = root.entries[list.currentIndex].id;
                        e.key === Qt.Key_E ? root.archive(id) : root.trash(id);
                    }
                    break;
                default:
                    return;
                }
            }
            e.accepted = true;
        }
        // Escape: reader → list, search cleared / left, otherwise close.
        Keys.onEscapePressed: e => {
            if (root.help)
                root.help = false;
            else if (root.readingId !== "")
                root.back();
            else if (search.text !== "" || search.editing)
                search.clear();
            else {
                e.accepted = false;
                return;
            }
            keys.forceActiveFocus();
        }

        // List page — slides a little left and fades as the reader comes in.
        ColumnLayout {
            id: listPage
            width: parent.width
            height: parent.height
            x: root.readingId !== "" ? -width * 0.3 : 0
            opacity: root.readingId !== "" ? 0 : 1
            // Visible at once when coming back (not after the fade starts), so
            // its search can take the focus right away.
            visible: opacity > 0 || root.readingId === ""
            spacing: Theme.gap + 2
            Behavior on x { NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: Theme.durShort } }

            // Height with everything shown at full size. The list's is counted
            // from its rows (ListView only builds the rows it has room for, so
            // its contentHeight can't size it).
            readonly property real listHeight: {
                let h = 0, prev = "";
                for (let i = 0; i < root.entries.length; i++) {
                    const g = root.dayGroup(root.entries[i].date);
                    h += root.rowHeight + (g !== prev ? root.headerHeight(i) : 0);
                    prev = g;
                }
                return h;
            }
            readonly property real naturalHeight: {
                const parts = [filterRow.implicitHeight, search.implicitHeight, root.entries.length > 0 ? listHeight : empty.implicitHeight];
                if (footer.visible)
                    parts.push(footer.implicitHeight);
                return parts.reduce((a, b) => a + b, 0) + (parts.length - 1) * spacing;
            }

            RowLayout {
                id: filterRow
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: [["All", "inbox"], ["Unread", "mark_email_unread"], ["Starred", "star"]]
                    delegate: MButton {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        icon: modelData[1]
                        label: modelData[0]
                        filled: root.filter === index
                        onClicked: root.filter = index
                    }
                }
            }

            MTextField {
                id: search
                Layout.fillWidth: true
                icon: "search"
                placeholder: "Search mail"
            }

            // Empty state: takes the list's place, centred in a compact block.
            Item {
                id: empty
                visible: root.entries.length === 0
                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitHeight: emptyColumn.implicitHeight + Theme.padL * 3

                Column {
                    id: emptyColumn
                    anchors.centerIn: parent
                    spacing: Theme.gap

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 64
                        height: 64
                        radius: 32
                        color: Theme.surfaceContainer
                        MIcon {
                            anchors.centerIn: parent
                            text: !Mail.available ? "mail_off" : search.text !== "" ? "search_off" : root.filter === 1 ? "mark_email_read" : root.filter === 2 ? "star" : "inbox"
                            size: 30
                            color: Theme.surfaceVariantText
                        }
                    }
                    MText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        topPadding: 4
                        text: !Mail.available ? "No mail index" : search.text !== "" ? "No matches" : root.filter === 1 ? "All caught up" : root.filter === 2 ? "No starred mail" : "Inbox zero"
                        font.bold: true
                    }
                    MText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: !Mail.available ? "Is home/mail.nix set up?" : search.text !== "" ? "Nothing matches “" + search.text + "”" : root.filter === 1 ? "No unread mail in your inbox" : root.filter === 2 ? "Star mail to keep it here" : "Nothing left in your inbox"
                        muted: true
                        sizeDelta: -1
                    }
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.entries.length > 0
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                highlightFollowsCurrentItem: false
                currentIndex: 0
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                model: ScriptModel {
                    objectProp: "id"
                    values: root.entries
                }

                delegate: Column {
                    id: cell
                    required property var modelData
                    required property int index
                    readonly property var t: modelData
                    readonly property string group: root.dayGroup(t.date)
                    readonly property bool firstOfGroup: index === 0 || root.dayGroup(root.entries[index - 1]?.date ?? 0) !== group

                    width: ListView.view.width
                    spacing: 0

                    MText {
                        visible: cell.firstOfGroup
                        height: visible ? root.headerHeight(cell.index) : 0
                        verticalAlignment: Text.AlignBottom
                        bottomPadding: 6
                        leftPadding: 8
                        text: cell.group
                        sizeDelta: -2
                        font.bold: true
                        font.letterSpacing: 0.6
                        color: Theme.surfaceVariantText
                    }

                    ListRow {
                        id: row
                        width: parent.width
                        implicitHeight: root.rowHeight
                        selected: root.kbNav && list.currentIndex === cell.index
                        onClicked: {
                            list.currentIndex = cell.index;
                            root.openThread(cell.t.id);
                        }

                        // Unread marker on the left edge.
                        Rectangle {
                            visible: cell.t.unread
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            width: 3
                            height: 26
                            radius: 1.5
                            color: Theme.primary
                        }

                        RowLayout {
                            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                            spacing: Theme.gapL - 2

                            Avatar {
                                name: cell.t.sender
                                opacity: cell.t.unread ? 1 : 0.75
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    // Who's in it, then the message count for
                                    // conversations; the names elide only when
                                    // they run out of room.
                                    Item {
                                        Layout.fillWidth: true
                                        implicitHeight: people.implicitHeight
                                        MText {
                                            id: people
                                            width: Math.min(implicitWidth, parent.width - (count.visible ? count.implicitWidth + 4 : 0))
                                            text: cell.t.from
                                            font.bold: cell.t.unread
                                            elide: Text.ElideRight
                                        }
                                        MText {
                                            id: count
                                            visible: cell.t.count > 1
                                            x: people.width + 4
                                            anchors.baseline: people.baseline
                                            text: cell.t.count
                                            sizeDelta: -2
                                            muted: !cell.t.unread
                                            font.bold: cell.t.unread
                                        }
                                    }
                                    MIcon {
                                        visible: cell.t.attachments.length > 0
                                        text: "attach_file"
                                        size: 14
                                        color: Theme.surfaceVariantText
                                    }
                                    MIcon {
                                        visible: cell.t.starred
                                        text: "star"
                                        fill: true
                                        size: 14
                                        color: Theme.warn
                                    }
                                    MText {
                                        text: root.shortTime(cell.t.date)
                                        sizeDelta: -2
                                        color: cell.t.unread ? Theme.primary : Theme.surfaceVariantText
                                        font.bold: cell.t.unread
                                    }
                                }
                                MText {
                                    Layout.fillWidth: true
                                    text: cell.t.subject
                                    elide: Text.ElideRight
                                    color: cell.t.unread ? Theme.surfaceText : Qt.alpha(Theme.surfaceText, 0.8)
                                    font.weight: cell.t.unread ? Font.DemiBold : Font.Normal
                                    sizeDelta: -1
                                }
                                MText {
                                    Layout.fillWidth: true
                                    text: cell.t.snippet
                                    elide: Text.ElideRight
                                    muted: true
                                    sizeDelta: -2
                                }
                            }
                        }

                        // Quick actions, floating over the row's right end on hover.
                        Rectangle {
                            anchors { right: parent.right; rightMargin: 6; bottom: parent.bottom; bottomMargin: 6 }
                            implicitWidth: actions.implicitWidth + 4
                            implicitHeight: actions.implicitHeight + 4
                            radius: height / 2
                            color: Theme.surfaceContainer
                            opacity: row.hovered ? 1 : 0
                            visible: opacity > 0
                            Behavior on opacity { NumberAnimation { duration: 110 } }
                            Row {
                                id: actions
                                anchors.centerIn: parent
                                spacing: 0
                                Repeater {
                                    model: [
                                        { "icon": "star", "tip": "star" },
                                        { "icon": cell.t.unread ? "drafts" : "mark_email_unread", "tip": "read" },
                                        { "icon": "archive", "tip": "archive" },
                                        { "icon": "delete", "tip": "delete" }
                                    ]
                                    delegate: MIconButton {
                                        required property var modelData
                                        implicitWidth: 26
                                        implicitHeight: 26
                                        size: 16
                                        restColor: Theme.surfaceContainer
                                        active: modelData.tip === "star" && cell.t.starred
                                        activeColor: Theme.warn
                                        icon: modelData.icon
                                        onClicked: {
                                            const id = cell.t.id;
                                            switch (modelData.tip) {
                                            case "star":
                                                Mail.toggleStar(id);
                                                break;
                                            case "read":
                                                Mail.setRead(id, cell.t.unread);
                                                break;
                                            case "archive":
                                                root.archive(id);
                                                break;
                                            case "delete":
                                                root.trash(id);
                                                break;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            MText {
                id: footer
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                visible: Mail.available
                text: (Mail.syncing ? "Syncing…" : (Mail.mock ? "Preview data · " : "") + "Updated " + Qt.formatTime(new Date(Mail.lastSync), "hh:mm")) + "  ·  ? for shortcuts"
                sizeDelta: -3
                muted: true
            }
        }

        // Reader page — the conversation, sliding in from the right.
        ColumnLayout {
            id: readerPage
            width: parent.width
            height: parent.height
            x: root.readingId !== "" ? 0 : width
            visible: x < width
            spacing: Theme.gap + 2
            Behavior on x { NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } }

            // Keep the last conversation while sliding out.
            property var thread: null
            Connections {
                target: root
                function onReadingChanged() {
                    if (root.reading)
                        readerPage.thread = root.reading;
                }
            }
            readonly property var messages: thread ? Mail.conversations[thread.id] : undefined

            // Once a conversation has loaded, scroll to its first open message
            // (in a long one the latest sits below the folded history). Once
            // per open, so later updates (star, read) don't jump.
            property bool _scrolled: false
            onThreadChanged: _scrolled = false
            onMessagesChanged: if (messages !== undefined && !_scrolled) scrollTimer.restart()
            Timer {
                id: scrollTimer
                interval: 50 // let the cards lay out first
                onTriggered: {
                    readerPage._scrolled = true;
                    for (const c of stack.children) {
                        if (c.expanded) {
                            reader.contentY = Math.max(0, Math.min(c.y, reader.contentHeight - reader.height));
                            return;
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 2
                MIconButton {
                    icon: "arrow_back"
                    onClicked: root.back()
                }
                MText {
                    text: "Inbox"
                    muted: true
                    Layout.fillWidth: true
                }
                MIconButton {
                    icon: "star"
                    active: readerPage.thread?.starred ?? false
                    activeColor: Theme.warn
                    onClicked: Mail.toggleStar(readerPage.thread.id)
                }
                MIconButton {
                    icon: "mark_email_unread"
                    onClicked: {
                        Mail.setRead(readerPage.thread.id, false);
                        root.back();
                    }
                }
                MIconButton {
                    icon: "archive"
                    onClicked: root.archive(readerPage.thread.id)
                }
                MIconButton {
                    icon: "delete"
                    onClicked: root.trash(readerPage.thread.id)
                }
            }

            MText {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                text: readerPage.thread?.subject ?? ""
                wrapMode: Text.Wrap
                sizeDelta: 4
                font.bold: true
            }
            MText {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                Layout.bottomMargin: 4
                visible: (readerPage.thread?.count ?? 0) > 1
                text: (readerPage.thread?.count ?? 0) + " messages · " + (readerPage.thread?.from ?? "")
                elide: Text.ElideRight
                muted: true
                sizeDelta: -1
            }

            Flickable {
                id: reader
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentHeight: stack.implicitHeight + Theme.padL
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 4000

                MText {
                    visible: readerPage.messages === undefined
                    x: 4
                    text: "Loading…"
                    muted: true
                }

                Column {
                    id: stack
                    width: reader.width
                    spacing: Theme.gap

                    Repeater {
                        model: ScriptModel {
                            objectProp: "id"
                            values: readerPage.messages ?? []
                        }

                        // One message of the conversation.
                        delegate: Rectangle {
                            id: card
                            required property var modelData
                            required property int index
                            readonly property var m: modelData
                            readonly property var parts: root.splitQuote(m.text)
                            property bool expanded: false
                            property bool showQuoted: false
                            readonly property bool hovered: cardHover.hovered

                            // Open: the latest, plus the ones that were unread.
                            Component.onCompleted: {
                                const n = readerPage.messages.length;
                                expanded = index >= n - Math.max(1, root.openedUnread);
                            }

                            width: stack.width
                            implicitHeight: body.implicitHeight + 20
                            radius: Theme.radiusM
                            color: expanded ? Theme.surfaceContainer : hovered ? Theme.surfaceContainer : Theme.popout
                            border.width: expanded ? 0 : 1
                            border.color: Qt.alpha(Theme.outline, 0.5)
                            Behavior on color { ColorAnimation { duration: 110 } }
                            HoverHandler { id: cardHover }

                            // Your own messages: an accent edge.
                            Rectangle {
                                visible: card.m.mine
                                anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: 10; bottomMargin: 10 }
                                width: 3
                                radius: 1.5
                                color: Theme.primary
                            }

                            ColumnLayout {
                                id: body
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10; leftMargin: 12; rightMargin: 12 }
                                spacing: Theme.gap + 2

                                // Header — click to fold / unfold.
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Theme.gap + 2
                                    Avatar {
                                        name: card.m.from
                                        size: 28
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: Theme.gap
                                            MText {
                                                text: card.m.mine ? "Me" : card.m.from
                                                font.bold: true
                                                color: card.m.mine ? Theme.primary : Theme.surfaceText
                                                elide: Text.ElideRight
                                                Layout.maximumWidth: card.width * 0.55
                                            }
                                            MText {
                                                Layout.fillWidth: true
                                                visible: card.expanded && !card.m.mine
                                                text: card.m.address
                                                muted: true
                                                sizeDelta: -2
                                                elide: Text.ElideRight
                                            }
                                            Item {
                                                visible: !card.expanded || card.m.mine
                                                Layout.fillWidth: true
                                            }
                                            MIcon {
                                                visible: !card.expanded && card.m.attachments.length > 0
                                                text: "attach_file"
                                                size: 14
                                                color: Theme.surfaceVariantText
                                            }
                                            MIcon {
                                                visible: card.m.starred
                                                text: "star"
                                                fill: true
                                                size: 14
                                                color: Theme.warn
                                            }
                                            MText {
                                                text: card.expanded ? root.longTime(card.m.date) : root.shortTime(card.m.date)
                                                muted: true
                                                sizeDelta: -2
                                            }
                                        }
                                        // Folded: the first words of what's new.
                                        MText {
                                            Layout.fillWidth: true
                                            visible: !card.expanded
                                            text: card.parts.main.replace(/\s+/g, " ").trim()
                                            elide: Text.ElideRight
                                            muted: true
                                            sizeDelta: -1
                                        }
                                    }
                                    TapHandler {
                                        cursorShape: Qt.PointingHandCursor
                                        onTapped: card.expanded = !card.expanded
                                    }
                                }

                                Flow {
                                    Layout.fillWidth: true
                                    visible: card.expanded && card.m.attachments.length > 0
                                    spacing: Theme.gap
                                    Repeater {
                                        model: card.m.attachments
                                        delegate: AttachmentChip {
                                            messageId: card.m.id
                                        }
                                    }
                                }

                                TextEdit {
                                    Layout.fillWidth: true
                                    visible: card.expanded
                                    readOnly: true
                                    selectByMouse: true
                                    wrapMode: TextEdit.Wrap
                                    textFormat: TextEdit.RichText
                                    text: card.expanded ? root.bodyHtml(card.parts.main) : ""
                                    color: Theme.surfaceText
                                    selectionColor: Theme.primary
                                    selectedTextColor: Theme.primaryText
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize
                                    onLinkActivated: link => Qt.openUrlExternally(link)
                                    HoverHandler {
                                        cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.IBeamCursor
                                    }
                                }

                                // Quoted history: folded behind a "•••" pill.
                                Rectangle {
                                    visible: card.expanded && card.parts.quoted !== ""
                                    implicitWidth: 34
                                    implicitHeight: 16
                                    radius: 8
                                    color: quoteHover.hovered || card.showQuoted ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                                    Behavior on color { ColorAnimation { duration: 110 } }
                                    MText {
                                        anchors.centerIn: parent
                                        text: "•••"
                                        sizeDelta: -3
                                        muted: true
                                    }
                                    HoverHandler {
                                        id: quoteHover
                                        cursorShape: Qt.PointingHandCursor
                                    }
                                    TapHandler {
                                        onTapped: card.showQuoted = !card.showQuoted
                                    }
                                }
                                TextEdit {
                                    Layout.fillWidth: true
                                    visible: card.expanded && card.showQuoted
                                    readOnly: true
                                    selectByMouse: true
                                    wrapMode: TextEdit.Wrap
                                    textFormat: TextEdit.RichText
                                    text: visible ? root.bodyHtml(card.parts.quoted) : ""
                                    color: Theme.surfaceVariantText
                                    selectionColor: Theme.primary
                                    selectedTextColor: Theme.primaryText
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize - 1
                                    onLinkActivated: link => Qt.openUrlExternally(link)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
