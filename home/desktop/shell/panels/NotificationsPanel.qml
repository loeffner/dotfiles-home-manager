// Notification center ("notifications"). Two views:
//   • list — Active / History tabs (History has an All / Last hour / Today /
//     This week filter), grouped by app (newest first; "Show N more" expands).
//     Each entry: swipe or × to dismiss, tap to jump to the app's window, action
//     buttons while alive, and a bell-off chooser that creates a silence rule
//     from it (this title / this text / whole app; mute or block).
//   • settings (gear) — per-urgency timeouts (on-screen time + auto-clear, a
//     default plus per-app overrides; right-click a chip to reset), muted apps,
//     and a builder for title / text / app silence rules.
// Right-clicking the bar bell toggles Do Not Disturb. Keys: IslandPanel's
// rules (j/k select a card, Enter goes to its app, d dismisses, ⌫ leaves
// settings) plus the panel's own in `shortcuts`.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.island
import qs.services

IslandPanel {
    id: root
    panelId: "notifications"
    panelWidth: 400

    property int tab: 0 // 0 Active, 1 History
    property int view: 0 // 0 list, 1 settings
    property int histFilter: 0 // 0 All, 1 Last hour, 2 Today, 3 This week
    property bool editCrit: false // settings edit the critical timeouts

    onClosed: {
        view = 0;
        editCrit = false;
        selectedId = "";
    }

    // Cycle presets; per-app lists lead with `undefined` = inherit the default.
    readonly property var screenGlobal: [1, 2, 3, 5, 10, 30, -1]
    readonly property var screenApp: [undefined, 1, 2, 3, 5, 10, 30, -1]
    readonly property var dismissGlobal: [0, 300, 1800, 3600, 21600]
    readonly property var dismissApp: [undefined, 0, 300, 1800, 3600, 21600]
    function next(presets, cur) {
        return presets[(presets.indexOf(cur) + 1) % presets.length];
    }
    function fmtScreen(v) {
        return v === undefined ? "Default" : v < 0 ? "Never" : v + "s";
    }
    function fmtDismiss(v) {
        if (v === undefined)
            return "Default";
        if (v <= 0)
            return "Never";
        return v < 3600 ? Math.round(v / 60) + "m" : Math.round(v / 3600) + "h";
    }

    // Entries for the current tab, time-filtered, grouped by app.
    readonly property var groups: {
        let src = Notifications.history;
        if (tab === 0) {
            src = src.filter(e => Notifications.isLive(e.id));
        } else if (histFilter > 0) {
            const now = Date.now();
            const day = new Date();
            day.setHours(0, 0, 0, 0);
            const since = histFilter === 1 ? now - 3600000 : histFilter === 2 ? day.getTime() : now - 7 * 86400000;
            src = src.filter(e => e.time >= since);
        }
        return Notifications.groupByApp(src);
    }

    // ── Custom rule builder state ────────────────────────────────────────────
    readonly property var ruleFields: ["title", "body", "any", "app"]
    readonly property var ruleFieldLabels: ["Title", "Text", "Title or text", "Whole app"]
    readonly property var ruleOps: ["contains", "not_contains", "equals", "regex"]
    readonly property var ruleOpLabels: ["contains", "does not contain", "equals", "matches regex"]
    readonly property var ruleApps: ["", ...Notifications.prefs.knownApps]
    property int fieldIdx: 0
    property int opIdx: 0
    property int appIdx: 0
    property bool block: false
    readonly property bool wholeApp: ruleFields[fieldIdx] === "app"

    function addCustomRule() {
        const app = ruleApps[appIdx] || "";
        if (wholeApp && !app)
            return; // a whole-app rule needs a specific app
        Notifications.addRule(app, ruleFields[fieldIdx], patternField.text, block ? "block" : "mute", ruleOps[opIdx]);
        patternField.clear();
    }
    function ruleText(r) {
        if (r.field === "app")
            return "Whole app";
        const noun = r.field === "body" ? "Text" : r.field === "any" ? "Title/text" : "Title";
        const op = r.op || "contains";
        if (op === "regex")
            return noun + " matches /" + r.pattern + "/";
        if (op === "equals")
            return noun + " is “" + r.pattern + "”";
        if (op === "not_contains")
            return noun + " excludes “" + r.pattern + "”";
        return noun + " contains “" + r.pattern + "”";
    }

    // ── Keyboard (IslandPanel: "?" shows this) ───────────────────────────────
    // The selection runs over the cards as shown (a folded group shows one), by
    // id; it's highlighted only once the keys move it.
    property string selectedId: ""
    property var expandedApps: ({}) // appName -> true: "Show N more" unfolded
    readonly property var shownEntries: groups.reduce((all, g) => all.concat(expandedApps[g.appName] ? g.items : g.items.slice(0, 1)), [])

    function toggleExpanded(app) {
        const m = Object.assign({}, expandedApps);
        m[app] = !m[app];
        expandedApps = m;
    }
    // Scroll the list so a card is in view.
    function reveal(item) {
        const y = item.mapToItem(groupsCol, 0, 0).y;
        if (y < flick.contentY)
            flick.contentY = y;
        else if (y + item.height > flick.contentY + flick.height)
            flick.contentY = Math.min(y + item.height - flick.height, flick.contentHeight - flick.height);
    }

    shortcuts: [
        {
            "title": "Notifications",
            "keys": [
                [["Tab", "⇧Tab"], "Active / History"],
                [["j", "k"], "Move down / up"],
                [["Enter", "Space"], "Go to the app"],
                [["d", "Del"], "Dismiss"],
                [["m"], "Show more / less of that app"],
                [["f"], "Next history filter"],
                [["c"], "Clear all"],
                [["z"], "Do Not Disturb"],
                [["s"], "Settings"],
                [["⌫"], "Back from settings"]
            ]
        }
    ]
    function back() {
        if (view !== 1)
            return false;
        view = 0;
        return true;
    }
    function handleKey(e) {
        const i = shownEntries.findIndex(n => n.id === selectedId);
        const sel = shownEntries[i];
        switch (e.key) {
        case Qt.Key_Tab:
        case Qt.Key_Backtab: // two tabs: both directions just switch
            view = 0;
            tab = 1 - tab;
            selectedId = "";
            return true;
        case Qt.Key_J:
        case Qt.Key_Down:
        case Qt.Key_K:
        case Qt.Key_Up:
            {
                const down = e.key === Qt.Key_J || e.key === Qt.Key_Down;
                const next = shownEntries[i < 0 ? 0 : Math.max(0, Math.min(shownEntries.length - 1, i + (down ? 1 : -1)))];
                if (view === 0 && next)
                    selectedId = next.id;
                return true;
            }
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            if (sel && Niri.focusByApp(sel.desktopEntry, sel.appName))
                close();
            return true;
        case Qt.Key_D:
        case Qt.Key_Delete:
            if (sel) {
                // Keep a selection: the next card, else the previous one.
                const after = shownEntries[i + 1] ?? shownEntries[i - 1];
                selectedId = after ? after.id : "";
                const id = sel.id;
                Qt.callLater(() => Notifications.remove(id));
            }
            return true;
        case Qt.Key_M:
            if (sel)
                toggleExpanded(sel.appName);
            return true;
        case Qt.Key_F:
            view = 0;
            tab = 1;
            histFilter = (histFilter + 1) % 4;
            return true;
        case Qt.Key_C:
            Qt.callLater(() => Notifications.clearAll());
            return true;
        case Qt.Key_Z:
            Notifications.dnd = !Notifications.dnd;
            return true;
        case Qt.Key_S:
            view = view === 0 ? 1 : 0;
            return true;
        }
        return false;
    }

    // ── Header ───────────────────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.gap
        MIconButton {
            visible: root.view === 1
            icon: "arrow_back"
            raised: true
            onClicked: root.view = 0
        }
        MText {
            text: root.view === 1 ? "Settings" : "Notifications"
            sizeDelta: 1
            font.bold: true
            Layout.fillWidth: true
        }
        MIconButton {
            visible: root.view === 0
            icon: Notifications.dnd ? "do_not_disturb_on" : "do_not_disturb_off"
            active: Notifications.dnd
            raised: true
            onClicked: Notifications.dnd = !Notifications.dnd
        }
        MIconButton {
            visible: root.view === 0 && Notifications.history.length > 0
            icon: "delete"
            raised: true
            activeColor: Theme.urgent
            onClicked: Qt.callLater(() => Notifications.clearAll())
        }
        MIconButton {
            visible: root.view === 0
            icon: "settings"
            raised: true
            onClicked: root.view = 1
        }
    }

    // ══ List view ═══════════════════════════════════════════════════════════
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.view === 0
        spacing: Theme.gap

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gap
            MButton {
                Layout.fillWidth: true
                label: Notifications.activeCount > 0 ? "Active  " + Notifications.activeCount : "Active"
                filled: root.tab === 0
                onClicked: root.tab = 0
            }
            MButton {
                Layout.fillWidth: true
                label: "History"
                filled: root.tab === 1
                onClicked: root.tab = 1
            }
        }
        RowLayout {
            Layout.fillWidth: true
            visible: root.tab === 1
            spacing: 4
            Repeater {
                model: ["All", "Last hour", "Today", "This week"]
                delegate: MButton {
                    required property string modelData
                    required property int index
                    label: modelData
                    filled: root.histFilter === index
                    onClicked: root.histFilter = index
                }
            }
        }

        MText {
            Layout.fillWidth: true
            Layout.topMargin: Theme.pad
            Layout.bottomMargin: Theme.pad
            visible: root.groups.length === 0
            text: root.tab === 0 ? "No active notifications" : "No notifications"
            muted: true
            horizontalAlignment: Text.AlignHCenter
        }

        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 460)
            visible: root.groups.length > 0
            contentHeight: groupsCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: groupsCol
                width: flick.width
                spacing: Theme.gap

                Repeater {
                    model: ScriptModel {
                        objectProp: "appName"
                        values: root.groups
                    }
                    delegate: GroupView {}
                }
            }
        }
    }

    // One app's group: header (icon, name, count, mute, clear) + entries.
    component GroupView: ColumnLayout {
        id: group
        required property var modelData
        readonly property bool expanded: root.expandedApps[modelData.appName] === true
        Layout.fillWidth: true
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gap
            Item {
                implicitWidth: 18
                implicitHeight: 18
                Image {
                    id: gIcon
                    anchors.fill: parent
                    source: Notifications.iconSource(group.modelData.items[0])
                    sourceSize: Qt.size(18, 18)
                    fillMode: Image.PreserveAspectFit
                    visible: status === Image.Ready
                }
                MIcon {
                    anchors.centerIn: parent
                    visible: gIcon.status !== Image.Ready
                    text: "notifications"
                    size: 16
                    color: Theme.surfaceVariantText
                }
            }
            MText {
                text: group.modelData.appName || "Unknown"
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            MText {
                visible: group.modelData.count > 1
                text: "×" + group.modelData.count
                muted: true
                sizeDelta: -1
            }
            MIconButton {
                icon: Notifications.isMuted(group.modelData.appName) ? "volume_off" : "volume_up"
                size: 16
                implicitWidth: 24
                implicitHeight: 24
                active: Notifications.isMuted(group.modelData.appName)
                onClicked: Notifications.toggleMute(group.modelData.appName)
            }
            MIconButton {
                icon: "close"
                size: 16
                implicitWidth: 24
                implicitHeight: 24
                activeColor: Theme.urgent
                onClicked: {
                    const a = group.modelData.appName;
                    Qt.callLater(() => Notifications.clearApp(a));
                }
            }
        }

        Repeater {
            model: ScriptModel {
                objectProp: "id"
                values: group.expanded ? group.modelData.items : group.modelData.items.slice(0, 1)
            }
            delegate: EntryView {
                expandedGroup: group.expanded
            }
        }

        MText {
            visible: group.modelData.count > 1
            Layout.leftMargin: 10
            text: group.expanded ? "Show less" : "Show " + (group.modelData.count - 1) + " more"
            color: moreMa.containsMouse ? Theme.surfaceText : Theme.primary
            sizeDelta: -2
            Behavior on color { ColorAnimation { duration: 80 } }
            MouseArea {
                id: moreMa
                anchors.fill: parent
                anchors.margins: -3
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.toggleExpanded(group.modelData.appName)
            }
        }
    }

    // One notification: a card that can be swiped away (DragHandler drives the
    // offset; a Behavior smooths the snap-back), tapped to focus its window.
    component EntryView: Item {
        id: entry
        required property var modelData
        property bool expandedGroup: false
        readonly property bool critical: Notifications.isCritical(modelData)
        readonly property var actions: Notifications.actionsFor(modelData.id)
        property bool silenceOpen: false
        property bool silenceBlock: false
        property real swipeOffset: 0
        property bool dismissing: false
        readonly property bool selected: root.selectedId === modelData.id
        onSelectedChanged: if (selected)
            Qt.callLater(() => root.reveal(entry))

        Layout.fillWidth: true
        Layout.leftMargin: 10
        implicitHeight: card.implicitHeight
        clip: true

        function dismiss() {
            const id = modelData.id;
            Qt.callLater(() => Notifications.remove(id));
        }
        function silence(field, pattern) {
            Notifications.addRule(modelData.appName, field, pattern, silenceBlock ? "block" : "mute");
            silenceOpen = false;
        }

        DragHandler {
            id: swipe
            target: null
            yAxis.enabled: false
            grabPermissions: PointerHandler.CanTakeOverFromItems | PointerHandler.CanTakeOverFromHandlersOfDifferentType
            onActiveTranslationChanged: if (!entry.dismissing)
                entry.swipeOffset = activeTranslation.x
            onActiveChanged: {
                if (active || entry.dismissing)
                    return;
                if (Math.abs(entry.swipeOffset) > entry.width * 0.35) {
                    entry.dismissing = true;
                    fling.start();
                } else {
                    entry.swipeOffset = 0;
                }
            }
        }
        NumberAnimation {
            id: fling
            target: entry
            property: "swipeOffset"
            to: entry.swipeOffset > 0 ? entry.width : -entry.width
            duration: 200
            easing.type: Easing.OutCubic
            onStopped: entry.dismiss()
        }
        TapHandler {
            onTapped: if (Niri.focusByApp(entry.modelData.desktopEntry, entry.modelData.appName))
                root.close()
        }

        Rectangle {
            id: card
            width: parent.width
            implicitHeight: ecol.implicitHeight + Theme.pad
            x: entry.swipeOffset
            opacity: Math.max(0.2, 1 - Math.abs(entry.swipeOffset) / entry.width)
            radius: Theme.radiusM
            color: Theme.surfaceContainer
            border.width: entry.selected ? 2 : 1
            border.color: entry.selected ? Theme.primary : entry.critical ? Theme.urgent : Theme.outline
            Behavior on x {
                enabled: !swipe.active && !entry.dismissing
                NumberAnimation { duration: Theme.durShort; easing.type: Easing.OutCubic }
            }

            ColumnLayout {
                id: ecol
                anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: Theme.pad; rightMargin: Theme.gap; topMargin: Theme.gap }
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    MText {
                        text: entry.modelData.summary
                        color: entry.critical ? Theme.urgent : Theme.surfaceText
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    MText {
                        text: Qt.formatDateTime(new Date(entry.modelData.time), "HH:mm")
                        muted: true
                        sizeDelta: -2
                    }
                    MIconButton {
                        icon: "notifications_off"
                        size: 14
                        implicitWidth: 20
                        implicitHeight: 20
                        restColor: Theme.surfaceContainer
                        active: entry.silenceOpen
                        onClicked: entry.silenceOpen = !entry.silenceOpen
                    }
                    MIconButton {
                        icon: "close"
                        size: 14
                        implicitWidth: 20
                        implicitHeight: 20
                        restColor: Theme.surfaceContainer
                        activeColor: Theme.urgent
                        onClicked: entry.dismiss()
                    }
                }
                MText {
                    Layout.fillWidth: true
                    visible: (entry.modelData.body ?? "") !== ""
                    text: entry.modelData.body
                    muted: true
                    sizeDelta: -1
                    wrapMode: Text.WordWrap
                    textFormat: Text.PlainText // a stranger's text: markup could fetch remote images
                    maximumLineCount: entry.expandedGroup ? 6 : 2
                    elide: Text.ElideRight
                }
                Flow {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    visible: entry.actions.length > 0
                    spacing: Theme.gap
                    Repeater {
                        model: entry.actions
                        delegate: MButton {
                            required property var modelData
                            label: modelData.text
                            onClicked: {
                                modelData.invoke();
                                entry.dismiss();
                            }
                        }
                    }
                }
                // Silence chooser: a rule from this exact notification.
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    visible: entry.silenceOpen
                    spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.gap
                        MText { text: "Silence future:"; muted: true; sizeDelta: -2; Layout.fillWidth: true }
                        MButton { label: "Mute"; filled: !entry.silenceBlock; onClicked: entry.silenceBlock = false }
                        MButton { label: "Block"; filled: entry.silenceBlock; onClicked: entry.silenceBlock = true }
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: Theme.gap
                        MButton { label: "This title"; onClicked: entry.silence("title", entry.modelData.summary) }
                        MButton {
                            label: "This text"
                            visible: (entry.modelData.body ?? "") !== ""
                            onClicked: entry.silence("body", entry.modelData.body)
                        }
                        MButton { label: "Whole app"; onClicked: entry.silence("app", "") }
                    }
                }
            }
        }
    }

    // ══ Settings view ═══════════════════════════════════════════════════════
    Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(contentHeight, 500)
        visible: root.view === 1
        contentHeight: setCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: setCol
            width: parent.width
            spacing: Theme.gapL

            MText { text: "Timeouts"; font.bold: true }
            MText {
                Layout.fillWidth: true
                text: "On-screen toast time and auto-clear from history, split by urgency. Each app uses the default unless you override it. Right-click a chip to reset it."
                muted: true
                sizeDelta: -2
                wrapMode: Text.WordWrap
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.gap
                MButton { Layout.fillWidth: true; label: "Normal"; filled: !root.editCrit; onClicked: root.editCrit = false }
                MButton { Layout.fillWidth: true; label: "Critical"; filled: root.editCrit; onClicked: root.editCrit = true }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.gap
                Item { Layout.fillWidth: true }
                MText { text: "Screen"; Layout.preferredWidth: 80; horizontalAlignment: Text.AlignHCenter; muted: true; sizeDelta: -3 }
                MText { text: "Dismiss"; Layout.preferredWidth: 80; horizontalAlignment: Text.AlignHCenter; muted: true; sizeDelta: -3 }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.gap
                MText { text: "All apps (default)"; font.bold: true; Layout.fillWidth: true }
                MButton {
                    Layout.preferredWidth: 80
                    readonly property int cur: root.editCrit ? Notifications.prefs.defaultTimeoutCrit : Notifications.prefs.defaultTimeout
                    label: root.fmtScreen(cur)
                    onClicked: Notifications.setDefaultTimeout(root.next(root.screenGlobal, cur), root.editCrit)
                    onRightClicked: Notifications.setDefaultTimeout(root.editCrit ? -1 : 5, root.editCrit)
                }
                MButton {
                    Layout.preferredWidth: 80
                    readonly property int cur: root.editCrit ? Notifications.prefs.defaultAutoDismissCrit : Notifications.prefs.defaultAutoDismiss
                    label: root.fmtDismiss(cur)
                    onClicked: Notifications.setDefaultAutoDismiss(root.next(root.dismissGlobal, cur), root.editCrit)
                    onRightClicked: Notifications.setDefaultAutoDismiss(0, root.editCrit)
                }
            }
            Repeater {
                model: Notifications.prefs.knownApps
                delegate: RowLayout {
                    id: appRow
                    required property string modelData
                    readonly property var screenVal: Notifications.timeoutOverride(modelData, root.editCrit)
                    readonly property var dismissVal: Notifications.autoDismissOverride(modelData, root.editCrit)
                    Layout.fillWidth: true
                    spacing: Theme.gap
                    MText { text: appRow.modelData || "Unknown"; elide: Text.ElideRight; Layout.fillWidth: true }
                    MButton {
                        Layout.preferredWidth: 80
                        label: root.fmtScreen(appRow.screenVal)
                        filled: appRow.screenVal !== undefined
                        onClicked: Notifications.setAppTimeout(appRow.modelData, root.next(root.screenApp, appRow.screenVal), root.editCrit)
                        onRightClicked: Notifications.setAppTimeout(appRow.modelData, undefined, root.editCrit)
                    }
                    MButton {
                        Layout.preferredWidth: 80
                        label: root.fmtDismiss(appRow.dismissVal)
                        filled: appRow.dismissVal !== undefined
                        onClicked: Notifications.setAppAutoDismiss(appRow.modelData, root.next(root.dismissApp, appRow.dismissVal), root.editCrit)
                        onRightClicked: Notifications.setAppAutoDismiss(appRow.modelData, undefined, root.editCrit)
                    }
                }
            }
            MText {
                visible: Notifications.prefs.knownApps.length === 0
                Layout.fillWidth: true
                text: "Apps appear here after they first send a notification."
                muted: true
                sizeDelta: -2
                wrapMode: Text.WordWrap
            }

            Divider {}

            RowLayout {
                Layout.fillWidth: true
                MText { text: "Muted apps"; font.bold: true; Layout.fillWidth: true }
                MButton {
                    visible: Notifications.prefs.mutedApps.length > 0
                    label: "Clear all"
                    onClicked: Notifications.clearAllMutes()
                }
            }
            MText {
                visible: Notifications.prefs.mutedApps.length === 0
                Layout.fillWidth: true
                text: "No muted apps. Mute one with the speaker button on its group in the list."
                muted: true
                sizeDelta: -2
                wrapMode: Text.WordWrap
            }
            Repeater {
                model: Notifications.prefs.mutedApps
                delegate: RowLayout {
                    required property string modelData
                    Layout.fillWidth: true
                    spacing: Theme.gap
                    MIcon { text: "volume_off"; size: 16; color: Theme.surfaceVariantText }
                    MText { text: parent.modelData || "Unknown"; elide: Text.ElideRight; Layout.fillWidth: true }
                    MIconButton {
                        icon: "close"
                        size: 16
                        implicitWidth: 24
                        implicitHeight: 24
                        activeColor: Theme.urgent
                        onClicked: Notifications.unmute(parent.modelData)
                    }
                }
            }

            Divider {}

            RowLayout {
                Layout.fillWidth: true
                MText { text: "Silence rules"; font.bold: true; Layout.fillWidth: true }
                MButton {
                    visible: Notifications.prefs.silenceRules.length > 0
                    label: "Clear all"
                    onClicked: Notifications.clearRules()
                }
            }
            MText {
                Layout.fillWidth: true
                text: "Build a filter: pick what to match, the operator, and (optionally) one app. Regex is case-insensitive."
                muted: true
                sizeDelta: -2
                wrapMode: Text.WordWrap
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.gap
                MButton {
                    Layout.fillWidth: true
                    label: root.ruleFieldLabels[root.fieldIdx]
                    onClicked: root.fieldIdx = (root.fieldIdx + 1) % root.ruleFields.length
                }
                MButton {
                    Layout.fillWidth: true
                    visible: !root.wholeApp
                    label: root.ruleOpLabels[root.opIdx]
                    onClicked: root.opIdx = (root.opIdx + 1) % root.ruleOps.length
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.gap
                MButton {
                    Layout.fillWidth: true
                    label: root.appIdx === 0 ? "Any app" : (root.ruleApps[root.appIdx] || "Any app")
                    onClicked: root.appIdx = (root.appIdx + 1) % root.ruleApps.length
                }
                MButton { label: "Mute"; filled: !root.block; onClicked: root.block = false }
                MButton { label: "Block"; filled: root.block; onClicked: root.block = true }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.gap
                visible: !root.wholeApp
                MTextField {
                    id: patternField
                    Layout.fillWidth: true
                    icon: "filter_alt"
                    placeholder: root.ruleOps[root.opIdx] === "regex" ? "regex, e.g. ^Sync\\b" : "text to match…"
                    onAccepted: root.addCustomRule()
                }
                MIconButton {
                    icon: "add"
                    raised: true
                    onClicked: root.addCustomRule()
                }
            }
            MButton {
                visible: root.wholeApp
                opacity: root.appIdx === 0 ? 0.5 : 1
                label: root.appIdx === 0 ? "Pick an app above" : (root.block ? "Block " : "Mute ") + root.ruleApps[root.appIdx]
                onClicked: root.addCustomRule()
            }
            MText {
                visible: Notifications.prefs.silenceRules.length === 0
                Layout.fillWidth: true
                text: "No filters yet. Build one above, or use the bell-off icon on a notification to silence its title or text in one click."
                muted: true
                sizeDelta: -2
                wrapMode: Text.WordWrap
            }
            Repeater {
                model: Notifications.prefs.silenceRules
                delegate: RowLayout {
                    id: ruleRow
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Theme.gap
                    MIcon {
                        text: ruleRow.modelData.mode === "block" ? "block" : "notifications_off"
                        size: 16
                        color: ruleRow.modelData.mode === "block" ? Theme.urgent : Theme.surfaceVariantText
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        MText { Layout.fillWidth: true; text: root.ruleText(ruleRow.modelData); elide: Text.ElideRight }
                        MText {
                            text: (ruleRow.modelData.mode === "block" ? "Block" : "Mute") + " · " + (ruleRow.modelData.app || "Any app")
                            muted: true
                            sizeDelta: -3
                        }
                    }
                    MIconButton {
                        icon: "close"
                        size: 16
                        implicitWidth: 24
                        implicitHeight: 24
                        activeColor: Theme.urgent
                        onClicked: Notifications.removeRule(ruleRow.modelData.id)
                    }
                }
            }
        }
    }
}
