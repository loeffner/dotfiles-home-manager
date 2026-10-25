// Processes panel ("processes"): host / distro / CPU / GPU info beside CPU,
// Memory and GPU gauges (inner ring = temperature); clicking the CPU gauge
// reveals fan control. Below: All / Mine / System filter, search and a sortable,
// killable process list. Click a row (or select it with j/k, then Enter) to copy
// its PID. The list keeps its rows (and scroll position) across refreshes and
// freezes while the pointer is over it or a row is selected, so rows don't
// shuffle out from under the cursor. Keys: IslandPanel's rules.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.island
import qs.services

IslandPanel {
    id: root
    panelId: "processes"
    panelWidth: 540
    searchField: search

    property int filter: 0 // 0 All, 1 Mine, 2 System
    property int sortKey: 0 // 0 CPU, 1 MEM
    property string copiedPid: ""
    property string selectedPid: "" // the keyboard selection (j/k), by PID

    onOpened: selectedPid = ""

    function copyPid(pid) {
        Quickshell.execDetached(["wl-copy", "--", pid]);
        copiedPid = pid;
        copiedTimer.restart();
    }

    // ── Keyboard (IslandPanel: "?" shows this) ───────────────────────────────
    shortcuts: [
        {
            "title": "Processes",
            "keys": [
                [["Tab", "⇧Tab"], "All / Mine / System"],
                [["j", "k"], "Move down / up"],
                [["Enter", "Space"], "Copy its PID"],
                [["d", "Del"], "Kill it"],
                [["s"], "Sort by CPU / memory"],
                [["f"], "Fan control"]
            ]
        }
    ]
    function handleKey(e) {
        const i = shownRows.findIndex(p => p.pid === selectedPid);
        switch (e.key) {
        case Qt.Key_Tab:
        case Qt.Key_Backtab:
            filter = (filter + 3 + tabStep(e)) % 3;
            return true;
        case Qt.Key_J:
        case Qt.Key_Down:
        case Qt.Key_K:
        case Qt.Key_Up:
            {
                const down = e.key === Qt.Key_J || e.key === Qt.Key_Down;
                const next = i < 0 ? 0 : Math.max(0, Math.min(shownRows.length - 1, i + (down ? 1 : -1)));
                if (shownRows[next]) {
                    selectedPid = shownRows[next].pid;
                    procList.positionViewAtIndex(next, ListView.Contain);
                }
                return true;
            }
        case Qt.Key_Return:
        case Qt.Key_Enter:
        case Qt.Key_Space:
            if (i >= 0)
                copyPid(selectedPid);
            return true;
        case Qt.Key_D:
        case Qt.Key_Delete:
            if (i >= 0) {
                SystemStats.killProcess(selectedPid);
                selectedPid = ""; // unfreeze, so the list drops it
            }
            return true;
        case Qt.Key_S:
            sortKey = 1 - sortKey;
            return true;
        case Qt.Key_F:
            Fans.expanded = !Fans.expanded;
            return true;
        }
        return false;
    }

    // top may truncate an owner to 8 chars with a trailing "+".
    function isMine(u) {
        const me = SystemStats.user;
        return u === me || (u.length > 0 && u[u.length - 1] === "+" && me.indexOf(u.slice(0, -1)) === 0);
    }
    function shortCpu(s) {
        return (s || "").replace(/\(R\)|\(TM\)/g, "").replace(/\s*\d+-Core Processor/, "").replace(/\s*Processor$/, "").trim();
    }
    function shortGpu(s) {
        return (s || "").replace(/NVIDIA\s+(GeForce\s+)?/i, "").replace(/AMD\s+(Radeon\s+)?/i, "").replace(/\s*\(.*\)/, "").trim();
    }

    // Filtered + searched + sorted, capped (the tail is idle 0% processes).
    readonly property var rows: {
        const q = search.text.toLowerCase();
        const list = SystemStats.procsFull.filter(p => (filter !== 1 || isMine(p.user)) && (filter !== 2 || !isMine(p.user)) && (!q || p.comm.toLowerCase().indexOf(q) >= 0 || String(p.pid).indexOf(q) >= 0));
        list.sort((a, b) => sortKey === 0 ? b.cpu - a.cpu : b.mem - a.mem);
        return list.slice(0, 100);
    }
    // What the list shows: `rows`, except frozen while hovered or while a row is
    // selected with the keys (rows would shuffle out from under either).
    property var shownRows: []
    property bool hovering: false
    readonly property bool frozen: hovering || selectedPid !== ""
    onRowsChanged: if (!frozen)
        shownRows = rows
    onFrozenChanged: if (!frozen)
        shownRows = rows

    Timer {
        id: copiedTimer
        interval: 1200
        onTriggered: root.copiedPid = ""
    }

    // Fixed-width, right-anchored sort header; the caret always takes its space
    // (only its opacity toggles) so the header never shifts.
    component SortHeader: Item {
        id: sh
        property string label: ""
        property int key: 0
        Layout.preferredWidth: 52
        Layout.preferredHeight: shRow.implicitHeight
        Row {
            id: shRow
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 2
            MText { text: "▾"; opacity: root.sortKey === sh.key ? 1 : 0; color: Theme.primary; sizeDelta: -3 }
            MText { text: sh.label; color: root.sortKey === sh.key ? Theme.primary : Theme.surfaceVariantText; sizeDelta: -3 }
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: root.sortKey = sh.key
        }
    }

    PanelHeader {
        icon: "monitoring"
        title: "Processes"
        MText { text: root.rows.length + " shown"; muted: true; sizeDelta: -2 }
    }

    // System info + gauges.
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 2
        Layout.bottomMargin: 2
        spacing: Theme.gapL

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1
            MText { text: SystemStats.hostname || "localhost"; sizeDelta: 2; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
            MText { text: SystemStats.distro; muted: true; sizeDelta: -2; elide: Text.ElideRight; Layout.fillWidth: true }
            Item { implicitHeight: 4 }
            MText { text: root.shortCpu(SystemStats.cpuModel); muted: true; sizeDelta: -2; elide: Text.ElideRight; Layout.fillWidth: true }
            MText { visible: text !== ""; text: root.shortGpu(SystemStats.gpuName); muted: true; sizeDelta: -2; elide: Text.ElideRight; Layout.fillWidth: true }
        }

        CircleGauge {
            diameter: 92
            value: SystemStats.cpu
            value2: SystemStats.cpuTemp > 0 ? Math.min(1, SystemStats.cpuTemp / 100) : -1
            big: Math.round(SystemStats.cpu * 100) + "%"
            small: SystemStats.cpuTemp > 0 ? Math.round(SystemStats.cpuTemp) + "°C" : ""
            caption: Fans.expanded ? "Fans ▴" : "CPU"
            arcColor: SystemStats.cpu > 0.85 ? Theme.urgent : Theme.primary
            arcColor2: SystemStats.cpuTemp > 85 ? Theme.urgent : Theme.warn
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Fans.expanded = !Fans.expanded
            }
        }
        CircleGauge {
            diameter: 92
            value: SystemStats.mem
            big: Math.round(SystemStats.mem * 100) + "%"
            small: SystemStats.memUsedGB.toFixed(1) + "/" + SystemStats.memTotalGB.toFixed(0) + "G"
            caption: "Memory"
            arcColor: SystemStats.mem > 0.85 ? Theme.urgent : Theme.primary
        }
        CircleGauge {
            diameter: 92
            visible: SystemStats.gpuAvailable
            value: SystemStats.gpuUsage
            value2: SystemStats.gpuTemp > 0 ? Math.min(1, SystemStats.gpuTemp / 100) : -1
            big: Math.round(SystemStats.gpuUsage * 100) + "%"
            small: SystemStats.gpuTemp > 0 ? Math.round(SystemStats.gpuTemp) + "°C" : ""
            caption: "GPU"
            arcColor: SystemStats.gpuUsage > 0.85 ? Theme.urgent : Theme.primary
            arcColor2: SystemStats.gpuTemp > 85 ? Theme.urgent : Theme.warn
        }
    }

    // Fan control (revealed by the CPU gauge).
    ColumnLayout {
        Layout.fillWidth: true
        visible: Fans.expanded
        spacing: Theme.gap

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gap
            MIcon { text: "mode_fan"; size: 18; color: Theme.primary }
            MText { text: "Fan control"; font.bold: true; Layout.fillWidth: true }
        }
        MText {
            visible: !Fans.available
            Layout.fillWidth: true
            text: "No controllable fans detected — load the nct6775 module and the PWM udev rule."
            muted: true
            sizeDelta: -2
            wrapMode: Text.WordWrap
        }
        Repeater {
            // Kept in place across polls, so a slider being dragged isn't rebuilt.
            model: ScriptModel {
                objectProp: "idx"
                values: Fans.fans
            }
            delegate: RowLayout {
                id: fan
                required property var modelData
                required property int index
                Layout.fillWidth: true
                spacing: Theme.gap
                MText { text: "Fan " + (fan.index + 1); Layout.preferredWidth: 44 }
                MText { text: fan.modelData.rpm + " rpm"; muted: true; sizeDelta: -2; Layout.preferredWidth: 66 }
                MSlider {
                    Layout.fillWidth: true
                    value: fan.modelData.pct / 100
                    onMoved: v => Fans.setPct(fan.modelData.idx, v * 100)
                }
                MButton {
                    Layout.preferredWidth: 68
                    label: fan.modelData.manual ? "Manual" : "Auto"
                    filled: fan.modelData.manual
                    onClicked: Fans.setManual(fan.modelData.idx, !fan.modelData.manual)
                }
            }
        }
    }

    // Filter + search.
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.gap
        Repeater {
            model: ["All", "Mine", "System"]
            delegate: MButton {
                required property string modelData
                required property int index
                label: modelData
                filled: root.filter === index
                onClicked: root.filter = index
            }
        }
        MTextField {
            id: search
            Layout.fillWidth: true
            icon: "search"
            placeholder: "Search"
        }
    }

    // Column header — CPU / MEM sort (▾ marks the active key).
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.gap
        MText { text: "Process"; muted: true; sizeDelta: -3; Layout.fillWidth: true }
        SortHeader { label: "CPU"; key: 0 }
        SortHeader { label: "MEM"; key: 1 }
        Item { implicitWidth: 24 }
    }

    ListView {
        id: procList
        Layout.fillWidth: true
        Layout.preferredHeight: 280
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        spacing: 1
        cacheBuffer: 400
        model: ScriptModel {
            objectProp: "pid"
            values: root.shownRows
        }

        HoverHandler {
            onHoveredChanged: root.hovering = hovered
        }

        add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durShort } }
        remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: Theme.durShort } }
        move: Transition { NumberAnimation { property: "y"; duration: Theme.durMed; easing.type: Easing.OutCubic } }
        displaced: Transition { NumberAnimation { property: "y"; duration: Theme.durMed; easing.type: Easing.OutCubic } }

        delegate: ListRow {
            id: proc
            required property var modelData
            readonly property bool copied: root.copiedPid === modelData.pid

            width: ListView.view.width
            implicitHeight: 26
            selected: copied || modelData.pid === root.selectedPid
            onClicked: root.copyPid(modelData.pid)

            RowLayout {
                anchors { fill: parent; leftMargin: 6; rightMargin: 4 }
                spacing: Theme.gap
                MText { text: proc.modelData.comm; elide: Text.ElideRight; Layout.fillWidth: true }
                MText {
                    visible: proc.hovered || proc.copied
                    text: proc.copied ? "copied ✓" : "#" + proc.modelData.pid
                    color: proc.copied ? Theme.primary : Theme.surfaceVariantText
                    sizeDelta: -3
                }
                MText {
                    text: proc.modelData.cpu.toFixed(0) + "%"
                    color: proc.modelData.cpu > 50 ? Theme.warn : Theme.surfaceText
                    sizeDelta: -1
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: 52
                }
                MText {
                    text: proc.modelData.mem.toFixed(0) + "%"
                    muted: true
                    sizeDelta: -1
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: 52
                }
                // Kill — no background of its own, so the row keeps one highlight.
                MIcon {
                    text: "close"
                    size: 15
                    Layout.preferredWidth: 24
                    color: killMa.containsMouse ? Theme.urgent : Theme.surfaceVariantText
                    opacity: proc.hovered ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 110 } }
                    MouseArea {
                        id: killMa
                        anchors.fill: parent
                        anchors.margins: -3
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SystemStats.killProcess(proc.modelData.pid)
                    }
                }
            }
        }
    }
}
