// NotifCenter — Material-3 notification bell + center. Rebuilds the old
// NotifButton on the new Popout and the M-kit, reusing the Notifications
// singleton (grouping, history, DND, per-app mute, live actions, settings).
//
// Two views: the list (Active / History tabs, History has an All/Last hour/Today
// /This week time filter) and a settings pane (gear) with per-app on-screen time,
// auto-dismiss, and muted-app management. Sounds are emitted by Notifications
// itself (see Sound.qml). Right-click the bell toggles DND.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

Item {
    id: root
    required property var bar

    readonly property int activeCount: Notifications.history.filter(e => Notifications.liveFor(e.id) !== null).length
    property int tab: 0        // 0 = Active, 1 = History
    property int view: 0       // 0 = list, 1 = settings
    property int histFilter: 0 // 0 All, 1 Last hour, 2 Today, 3 This week
    property bool editCrit: false // settings: editing normal (false) or critical (true) timeouts

    // Cycle presets. Per-app lists lead with `undefined` = inherit the default.
    readonly property var screenGlobal: [1, 2, 3, 5, 10, 30, -1]
    readonly property var screenApp: [undefined, 1, 2, 3, 5, 10, 30, -1]
    readonly property var dismissGlobal: [0, 300, 1800, 3600, 21600]
    readonly property var dismissApp: [undefined, 0, 300, 1800, 3600, 21600]

    implicitWidth: bell.implicitWidth
    implicitHeight: Theme.barHeight

    function fmtScreen(v) {
        return v === undefined ? "Default" : (v < 0 ? "Never" : v + "s");
    }
    function fmtDismiss(v) {
        if (v === undefined)
            return "Default";
        if (v <= 0)
            return "Never";
        return v < 3600 ? (Math.round(v / 60) + "m") : (Math.round(v / 3600) + "h");
    }
    // ── Custom-filter builder state (settings) ──────────────────────────────
    readonly property var filterFields: ["title", "body", "any", "app"]
    readonly property var filterFieldLabels: ["Title", "Text", "Title or text", "Whole app"]
    readonly property var filterOps: ["contains", "not_contains", "equals", "regex"]
    readonly property var filterOpLabels: ["contains", "does not contain", "equals", "matches regex"]
    readonly property var filterApps: ["", ...Notifications.knownApps]
    property int fFieldIdx: 0
    property int fOpIdx: 0
    property int fAppIdx: 0
    property bool fBlock: false

    function _fieldNoun(f) {
        return f === "body" ? "Text" : (f === "any" ? "Title/text" : "Title");
    }
    function silenceRuleText(r) {
        if (r.field === "app")
            return "Whole app";
        const noun = root._fieldNoun(r.field);
        const op = r.op || "contains";
        if (op === "regex")
            return noun + " matches /" + r.pattern + "/";
        if (op === "equals")
            return noun + " is “" + r.pattern + "”";
        if (op === "not_contains")
            return noun + " excludes “" + r.pattern + "”";
        return noun + " contains “" + r.pattern + "”";
    }
    function addCustomFilter() {
        const field = root.filterFields[root.fFieldIdx];
        const op = root.filterOps[root.fOpIdx];
        const app = root.filterApps[root.fAppIdx] || "";
        if (field === "app" && !app)
            return; // a whole-app rule needs a specific app
        Notifications.addSilenceRule(app, field, filterField.text, root.fBlock ? "block" : "mute", op);
        filterField.clear();
    }
    function _next(presets, cur) {
        const i = presets.indexOf(cur); // -1 (not found) -> starts at presets[0]
        return presets[(i + 1) % presets.length];
    }
    // Per-app override for the currently-edited urgency track (root.editCrit).
    function appScreen(app) {
        return Notifications.hasTimeout(app, root.editCrit) ? (root.editCrit ? Notifications.appTimeoutsCrit[app] : Notifications.appTimeouts[app]) : undefined;
    }
    function appDismiss(app) {
        return Notifications.hasAutoDismiss(app, root.editCrit) ? (root.editCrit ? Notifications.appAutoDismissCrit[app] : Notifications.appAutoDismiss[app]) : undefined;
    }
    function cycleScreenApp(app) {
        Notifications.setAppTimeout(app, root._next(root.screenApp, root.appScreen(app)), root.editCrit);
    }
    function cycleDismissApp(app) {
        Notifications.setAppAutoDismiss(app, root._next(root.dismissApp, root.appDismiss(app)), root.editCrit);
    }

    // Apply the History time filter, then group by app (recency-preserving).
    function groups(activeOnly) {
        let src = activeOnly ? Notifications.history.filter(e => Notifications.liveFor(e.id) !== null) : Notifications.history;
        if (!activeOnly && root.histFilter > 0) {
            const now = Date.now();
            if (root.histFilter === 1)
                src = src.filter(e => e.time >= now - 3600000);
            else if (root.histFilter === 2) {
                const d = new Date();
                d.setHours(0, 0, 0, 0);
                src = src.filter(e => e.time >= d.getTime());
            } else if (root.histFilter === 3)
                src = src.filter(e => e.time >= now - 7 * 86400000);
        }
        const map = {}, order = [];
        for (const e of src) {
            const k = e.appName || "";
            if (!(k in map)) {
                map[k] = [];
                order.push(k);
            }
            map[k].push(e);
        }
        return order.map(k => ({
                    "appName": k,
                    "items": map[k],
                    "count": map[k].length
                }));
    }

    // ── Bell ────────────────────────────────────────────────────────────────
    MIcon {
        id: bell
        anchors.centerIn: parent
        text: Notifications.dnd ? "notifications_off" : (root.activeCount > 0 ? "notifications_active" : "notifications")
        size: 20
        fill: pop.isOpen
        color: Notifications.dnd ? Theme.surfaceVariantText : (pop.isOpen || root.activeCount > 0 ? Theme.primary : (ma.containsMouse ? Theme.iconHover : Theme.surfaceText))
        scale: ma.containsMouse ? 1.15 : 1.0
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }
    Rectangle {
        visible: root.activeCount > 0 && !Notifications.dnd
        anchors { right: bell.right; top: bell.top; rightMargin: -2; topMargin: 1 }
        width: 8
        height: 8
        radius: 4
        color: Theme.primary
        border.width: 2
        border.color: Theme.bar
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: e => e.button === Qt.RightButton ? (Notifications.dnd = !Notifications.dnd) : pop.toggle()
    }

    Popout {
        id: pop
        bar: root.bar
        anchorItem: root
        popId: "notifications"
        popWidth: 400
        // The custom-filter builder (settings) has a text field; let it grab
        // keyboard focus while being edited.
        wantsFocus: filterField.wantFocus

        Connections {
            target: pop
            function onIsOpenChanged() {
                if (!pop.isOpen) {
                    root.view = 0;
                    root.editCrit = false;
                }
            }
        }

        // ── Header ───────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gap

            MIconButton {
                visible: root.view === 1
                icon: "arrow_back"
                raised: true
                onClicked: root.view = 0
            }
            Text {
                text: root.view === 1 ? "Settings" : "Notifications"
                color: Theme.surfaceText
                font.family: Theme.font
                font.pixelSize: Theme.fontSize + 1
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

        // ══ LIST VIEW ═════════════════════════════════════════════════════════
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.view === 0
            spacing: Theme.gap

            // Tabs
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.gap
                MButton {
                    Layout.fillWidth: true
                    label: root.activeCount > 0 ? ("Active  " + root.activeCount) : "Active"
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

            // History time filter
            RowLayout {
                Layout.fillWidth: true
                visible: root.tab === 1
                spacing: 4
                Repeater {
                    model: ["All", "Last hour", "Today", "This week"]
                    delegate: MButton {
                        required property var modelData
                        required property int index
                        label: modelData
                        filled: root.histFilter === index
                        onClicked: root.histFilter = index
                    }
                }
            }

            // Empty state
            Text {
                Layout.fillWidth: true
                Layout.topMargin: Theme.pad
                Layout.bottomMargin: Theme.pad
                visible: root.groups(root.tab === 0).length === 0
                text: root.tab === 0 ? "No active notifications" : "No notifications"
                color: Theme.surfaceVariantText
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                horizontalAlignment: Text.AlignHCenter
            }

            // Scrollable groups
            Flickable {
                id: flick
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(contentHeight, 460)
                visible: root.groups(root.tab === 0).length > 0
                contentHeight: groupsCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: groupsCol
                    width: flick.width
                    spacing: Theme.gap

                    Repeater {
                        model: root.groups(root.tab === 0)

                        delegate: ColumnLayout {
                            id: group
                            required property var modelData
                            property bool expanded: false
                            readonly property var items: modelData.items
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
                                        source: Notifications.iconSource(group.items[0])
                                        sourceSize.width: 18
                                        sourceSize.height: 18
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
                                Text {
                                    text: group.modelData.appName || "Unknown"
                                    color: Theme.surfaceText
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize
                                    font.bold: true
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    visible: group.modelData.count > 1
                                    text: "×" + group.modelData.count
                                    color: Theme.surfaceVariantText
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize - 1
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
                                model: group.expanded ? group.items : group.items.slice(0, 1)

                                delegate: Item {
                                    id: entry
                                    required property var modelData
                                    readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
                                    readonly property var acts: Notifications.actionsFor(modelData.id)
                                    property bool silenceOpen: false
                                    property bool silenceBlock: false // false = mute, true = block
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 10
                                    implicitHeight: card.implicitHeight
                                    clip: true

                                    // Slide-to-dismiss — DankMaterialShell's technique: a
                                    // DragHandler drives swipeOffset, the card's x binds to it,
                                    // and Behavior on x smooths snap-back (disabled while
                                    // dragging/dismissing so those stay 1:1 / fling-driven).
                                    property real swipeOffset: 0
                                    property bool isDismissing: false
                                    readonly property real dismissThreshold: width * 0.35

                                    DragHandler {
                                        id: swipeHandler
                                        target: null
                                        xAxis.enabled: true
                                        yAxis.enabled: false
                                        grabPermissions: PointerHandler.CanTakeOverFromItems | PointerHandler.CanTakeOverFromHandlersOfDifferentType
                                        onActiveTranslationChanged: {
                                            if (!entry.isDismissing)
                                                entry.swipeOffset = activeTranslation.x;
                                        }
                                        onActiveChanged: {
                                            if (active || entry.isDismissing)
                                                return;
                                            if (Math.abs(entry.swipeOffset) > entry.dismissThreshold) {
                                                entry.isDismissing = true;
                                                flingAnim.start();
                                            } else {
                                                entry.swipeOffset = 0;
                                            }
                                        }
                                    }
                                    NumberAnimation {
                                        id: flingAnim
                                        target: entry
                                        property: "swipeOffset"
                                        to: entry.swipeOffset > 0 ? entry.width : -entry.width
                                        duration: 200
                                        easing.type: Easing.OutCubic
                                        onStopped: {
                                            const id = entry.modelData.id;
                                            Qt.callLater(() => Notifications.removeById(id));
                                        }
                                    }
                                    // A tap (not a drag) jumps to the producing window.
                                    TapHandler {
                                        onTapped: {
                                            if (Niri.focusByApp(entry.modelData.desktopEntry, entry.modelData.appName))
                                                pop.close();
                                        }
                                    }

                                    Rectangle {
                                        id: card
                                        width: parent.width
                                        implicitHeight: ecol.implicitHeight + Theme.pad
                                        x: entry.swipeOffset
                                        opacity: Math.max(0.2, 1 - Math.abs(entry.swipeOffset) / entry.width)
                                        radius: Theme.radiusM
                                        color: Theme.surfaceContainer
                                        border.width: 1
                                        border.color: entry.critical ? Theme.urgent : Theme.outline

                                        Behavior on x {
                                            enabled: !swipeHandler.active && !entry.isDismissing
                                            NumberAnimation { duration: Theme.durShort; easing.type: Easing.OutCubic }
                                        }

                                        ColumnLayout {
                                            id: ecol
                                            anchors { left: parent.left; right: parent.right; top: parent.top }
                                            anchors { leftMargin: Theme.pad; rightMargin: Theme.gap; topMargin: Theme.gap }
                                            spacing: 2

                                            RowLayout {
                                                Layout.fillWidth: true
                                                Text {
                                                    text: entry.modelData.summary
                                                    color: entry.critical ? Theme.urgent : Theme.surfaceText
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.fontSize
                                                    font.bold: true
                                                    elide: Text.ElideRight
                                                    Layout.fillWidth: true
                                                }
                                                Text {
                                                    text: Qt.formatDateTime(new Date(entry.modelData.time), "HH:mm")
                                                    color: Theme.surfaceVariantText
                                                    font.family: Theme.font
                                                    font.pixelSize: Theme.fontSize - 2
                                                }
                                                // Silence this kind of notification — reveals the
                                                // title/text/app choices below (no typing needed).
                                                MIconButton {
                                                    icon: "notifications_off"
                                                    size: 14
                                                    implicitWidth: 20
                                                    implicitHeight: 20
                                                    active: entry.silenceOpen
                                                    onClicked: entry.silenceOpen = !entry.silenceOpen
                                                }
                                                MIconButton {
                                                    icon: "close"
                                                    size: 14
                                                    implicitWidth: 20
                                                    implicitHeight: 20
                                                    activeColor: Theme.urgent
                                                    onClicked: {
                                                        const id = entry.modelData.id;
                                                        Qt.callLater(() => Notifications.removeById(id));
                                                    }
                                                }
                                            }
                                            Text {
                                                Layout.fillWidth: true
                                                visible: (entry.modelData.body ?? "") !== ""
                                                text: entry.modelData.body
                                                color: Theme.surfaceVariantText
                                                font.family: Theme.font
                                                font.pixelSize: Theme.fontSize - 1
                                                wrapMode: Text.WordWrap
                                                textFormat: Text.MarkdownText
                                                maximumLineCount: group.expanded ? 6 : 2
                                                elide: Text.ElideRight
                                            }

                                            Flow {
                                                Layout.fillWidth: true
                                                Layout.topMargin: 2
                                                visible: entry.acts.length > 0
                                                spacing: Theme.gap
                                                Repeater {
                                                    model: entry.acts
                                                    delegate: MButton {
                                                        required property var modelData
                                                        label: modelData.text
                                                        onClicked: {
                                                            modelData.invoke();
                                                            const id = entry.modelData.id;
                                                            Qt.callLater(() => Notifications.removeById(id));
                                                        }
                                                    }
                                                }
                                            }

                                            // Silence chooser — creates a filter from this exact
                                            // notification (its title, body text, or the whole app).
                                            // Mute keeps it in history; Block discards it entirely.
                                            // No keyboard needed; refine/remove in Settings.
                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                Layout.topMargin: 4
                                                visible: entry.silenceOpen
                                                spacing: 4

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: Theme.gap
                                                    Text {
                                                        Layout.fillWidth: true
                                                        Layout.alignment: Qt.AlignVCenter
                                                        text: "Silence future:"
                                                        color: Theme.surfaceVariantText
                                                        font.family: Theme.font
                                                        font.pixelSize: Theme.fontSize - 2
                                                    }
                                                    MButton {
                                                        label: "Mute"
                                                        filled: !entry.silenceBlock
                                                        onClicked: entry.silenceBlock = false
                                                    }
                                                    MButton {
                                                        label: "Block"
                                                        filled: entry.silenceBlock
                                                        onClicked: entry.silenceBlock = true
                                                    }
                                                }

                                                Flow {
                                                    Layout.fillWidth: true
                                                    spacing: Theme.gap
                                                    MButton {
                                                        label: "This title"
                                                        onClicked: {
                                                            Notifications.addSilenceRule(entry.modelData.appName, "title", entry.modelData.summary, entry.silenceBlock ? "block" : "mute");
                                                            entry.silenceOpen = false;
                                                        }
                                                    }
                                                    MButton {
                                                        label: "This text"
                                                        visible: (entry.modelData.body ?? "") !== ""
                                                        onClicked: {
                                                            Notifications.addSilenceRule(entry.modelData.appName, "body", entry.modelData.body, entry.silenceBlock ? "block" : "mute");
                                                            entry.silenceOpen = false;
                                                        }
                                                    }
                                                    MButton {
                                                        label: "Whole app"
                                                        onClicked: {
                                                            Notifications.addSilenceRule(entry.modelData.appName, "app", "", entry.silenceBlock ? "block" : "mute");
                                                            entry.silenceOpen = false;
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                visible: group.modelData.count > 1
                                Layout.leftMargin: 10
                                text: group.expanded ? "Show less" : ("Show " + (group.modelData.count - 1) + " more")
                                color: moreMa.containsMouse ? Theme.surfaceText : Theme.primary
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize - 2
                                Behavior on color { ColorAnimation { duration: 80 } }
                                MouseArea {
                                    id: moreMa
                                    anchors.fill: parent
                                    anchors.margins: -3
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: group.expanded = !group.expanded
                                }
                            }
                        }
                    }
                }
            }
        }

        // ══ SETTINGS VIEW ═════════════════════════════════════════════════════
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

                // ── Timeouts: on-screen time + auto-dismiss, default + per app ──
                Text {
                    text: "Timeouts"
                    color: Theme.surfaceText
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                }
                Text {
                    Layout.fillWidth: true
                    text: "On-screen toast time and auto-clear from history, split by urgency. Each app uses the default unless you override it. Right-click a chip to reset it."
                    color: Theme.surfaceVariantText
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 2
                    wrapMode: Text.WordWrap
                }

                // Normal / Critical selector — re-targets the whole table below.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.gap
                    MButton {
                        Layout.fillWidth: true
                        label: "Normal"
                        filled: !root.editCrit
                        onClicked: root.editCrit = false
                    }
                    MButton {
                        Layout.fillWidth: true
                        label: "Critical"
                        filled: root.editCrit
                        onClicked: root.editCrit = true
                    }
                }

                // Column headers
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.gap
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "Screen"
                        Layout.preferredWidth: 80
                        horizontalAlignment: Text.AlignHCenter
                        color: Theme.surfaceVariantText
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 3
                    }
                    Text {
                        text: "Dismiss"
                        Layout.preferredWidth: 80
                        horizontalAlignment: Text.AlignHCenter
                        color: Theme.surfaceVariantText
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 3
                    }
                }

                // Default row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.gap
                    Text {
                        text: "All apps (default)"
                        color: Theme.surfaceText
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    MButton {
                        Layout.preferredWidth: 80
                        readonly property int cur: root.editCrit ? Notifications.defaultTimeoutCrit : Notifications.defaultTimeout
                        label: root.fmtScreen(cur)
                        onClicked: Notifications.setDefaultTimeout(root._next(root.screenGlobal, cur), root.editCrit)
                        onRightClicked: Notifications.setDefaultTimeout(root.editCrit ? -1 : 5, root.editCrit) // factory
                    }
                    MButton {
                        Layout.preferredWidth: 80
                        readonly property int cur: root.editCrit ? Notifications.defaultAutoDismissCrit : Notifications.defaultAutoDismiss
                        label: root.fmtDismiss(cur)
                        onClicked: Notifications.setDefaultAutoDismiss(root._next(root.dismissGlobal, cur), root.editCrit)
                        onRightClicked: Notifications.setDefaultAutoDismiss(0, root.editCrit) // factory
                    }
                }

                // Per-app rows
                Repeater {
                    model: Notifications.knownApps
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Theme.gap
                        Text {
                            text: modelData || "Unknown"
                            color: Theme.surfaceText
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        MButton {
                            Layout.preferredWidth: 80
                            label: root.fmtScreen(root.appScreen(modelData))
                            filled: Notifications.hasTimeout(modelData, root.editCrit)
                            onClicked: root.cycleScreenApp(modelData)
                            onRightClicked: Notifications.setAppTimeout(modelData, undefined, root.editCrit) // back to Default
                        }
                        MButton {
                            Layout.preferredWidth: 80
                            label: root.fmtDismiss(root.appDismiss(modelData))
                            filled: Notifications.hasAutoDismiss(modelData, root.editCrit)
                            onClicked: root.cycleDismissApp(modelData)
                            onRightClicked: Notifications.setAppAutoDismiss(modelData, undefined, root.editCrit) // back to Default
                        }
                    }
                }
                Text {
                    visible: Notifications.knownApps.length === 0
                    Layout.fillWidth: true
                    text: "Apps appear here after they first send a notification."
                    color: Theme.surfaceVariantText
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 2
                    wrapMode: Text.WordWrap
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.outline; opacity: 0.4 }

                // Muted apps
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Muted apps"
                        color: Theme.surfaceText
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    MButton {
                        visible: Notifications.mutedApps.length > 0
                        label: "Clear all"
                        onClicked: Notifications.clearAllMutes()
                    }
                }
                Text {
                    visible: Notifications.mutedApps.length === 0
                    Layout.fillWidth: true
                    text: "No muted apps. Mute one from its group header or the bell's right-click."
                    color: Theme.surfaceVariantText
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 2
                    wrapMode: Text.WordWrap
                }
                Repeater {
                    model: Notifications.mutedApps
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Theme.gap
                        MIcon {
                            text: "volume_off"
                            size: 16
                            color: Theme.surfaceVariantText
                        }
                        Text {
                            text: modelData || "Unknown"
                            color: Theme.surfaceText
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        MIconButton {
                            icon: "close"
                            size: 16
                            implicitWidth: 24
                            implicitHeight: 24
                            activeColor: Theme.urgent
                            onClicked: Notifications.unmute(modelData)
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.outline; opacity: 0.4 }

                // ── Silence rules (title/text filters) ──────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Silence rules"
                        color: Theme.surfaceText
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    MButton {
                        visible: Notifications.silenceRules.length > 0
                        label: "Clear all"
                        onClicked: Notifications.clearSilenceRules()
                    }
                }

                // ── Custom-filter builder ───────────────────────────────────────
                Text {
                    Layout.fillWidth: true
                    text: "Build a filter: pick what to match, the operator, and (optionally) one app. Regex is case-insensitive."
                    color: Theme.surfaceVariantText
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 2
                    wrapMode: Text.WordWrap
                }
                // Field + operator
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.gap
                    MButton {
                        Layout.fillWidth: true
                        label: root.filterFieldLabels[root.fFieldIdx]
                        onClicked: root.fFieldIdx = (root.fFieldIdx + 1) % root.filterFields.length
                    }
                    MButton {
                        Layout.fillWidth: true
                        visible: root.filterFields[root.fFieldIdx] !== "app"
                        label: root.filterOpLabels[root.fOpIdx]
                        onClicked: root.fOpIdx = (root.fOpIdx + 1) % root.filterOps.length
                    }
                }
                // App scope + mode
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.gap
                    MButton {
                        Layout.fillWidth: true
                        label: root.fAppIdx === 0 ? "Any app" : (root.filterApps[root.fAppIdx] || "Any app")
                        onClicked: root.fAppIdx = (root.fAppIdx + 1) % root.filterApps.length
                    }
                    MButton {
                        label: "Mute"
                        filled: !root.fBlock
                        onClicked: root.fBlock = false
                    }
                    MButton {
                        label: "Block"
                        filled: root.fBlock
                        onClicked: root.fBlock = true
                    }
                }
                // Pattern + add (text fields only). Whole-app rules need no pattern.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.gap
                    visible: root.filterFields[root.fFieldIdx] !== "app"
                    MTextField {
                        id: filterField
                        Layout.fillWidth: true
                        icon: "filter_alt"
                        placeholder: root.filterOps[root.fOpIdx] === "regex" ? "regex, e.g. ^Sync\\b" : "text to match…"
                        onAccepted: root.addCustomFilter()
                    }
                    MIconButton {
                        icon: "add"
                        raised: true
                        onClicked: root.addCustomFilter()
                    }
                }
                MButton {
                    visible: root.filterFields[root.fFieldIdx] === "app"
                    opacity: root.fAppIdx === 0 ? 0.5 : 1
                    label: root.fAppIdx === 0 ? "Pick an app above" : ((root.fBlock ? "Block " : "Mute ") + root.filterApps[root.fAppIdx])
                    onClicked: root.addCustomFilter()
                }

                Text {
                    visible: Notifications.silenceRules.length === 0
                    Layout.fillWidth: true
                    text: "No filters yet. Build one above, or use the bell-off icon on a notification to silence its title or text in one click."
                    color: Theme.surfaceVariantText
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 2
                    wrapMode: Text.WordWrap
                }
                Repeater {
                    model: Notifications.silenceRules
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Theme.gap
                        MIcon {
                            text: (modelData.mode === "block") ? "block" : "notifications_off"
                            size: 16
                            color: (modelData.mode === "block") ? Theme.urgent : Theme.surfaceVariantText
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                Layout.fillWidth: true
                                text: root.silenceRuleText(modelData)
                                color: Theme.surfaceText
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize
                                elide: Text.ElideRight
                            }
                            Text {
                                text: ((modelData.mode === "block") ? "Block" : "Mute") + " · " + (modelData.app ? modelData.app : "Any app")
                                color: Theme.surfaceVariantText
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize - 3
                            }
                        }
                        MIconButton {
                            icon: "close"
                            size: 16
                            implicitWidth: 24
                            implicitHeight: 24
                            activeColor: Theme.urgent
                            onClicked: Notifications.removeSilenceRule(modelData.id)
                        }
                    }
                }
            }
        }
    }
}
