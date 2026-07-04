// SysPill — a single system-monitor icon (no numbers) that opens the Processes
// panel (≈ DankMaterialShell's ProcessListPopout): CPU/Memory/GPU circular
// gauges, an All/Mine/System filter + search, and a killable process list.
// Data comes from SystemStats (dgop); polling quickens while open.
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    required property var bar
    property int procFilter: 0 // 0 All, 1 Mine, 2 System
    property int sortKey: 0    // 0 = CPU, 1 = MEM
    property string copiedPid: "" // pid just copied to clipboard (transient badge)
    property bool fansOpen: false // fan-control section (toggled by the CPU gauge)

    implicitWidth: icon.implicitWidth
    implicitHeight: Theme.barHeight

    // top may truncate the owner to 8 chars with a trailing "+".
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

    // Fixed-width, right-anchored sort column header. The caret always occupies
    // space (only its opacity toggles) and the label is right-anchored, so the
    // header never shifts when you switch the active sort key.
    component SortHeader: Item {
        id: sh
        property string label: ""
        property int key: 0
        Layout.preferredWidth: 52
        Layout.preferredHeight: shRow.implicitHeight
        Row {
            id: shRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                text: "▾"
                opacity: root.sortKey === sh.key ? 1 : 0
                color: Theme.primary
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 3
            }
            Text {
                text: sh.label
                color: root.sortKey === sh.key ? Theme.primary : Theme.surfaceVariantText
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 3
            }
        }
        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: root.sortKey = sh.key
        }
    }

    // Filtered + searched + sorted view of the full process list (capped so the
    // in-place model reconcile stays cheap; the tail is idle 0% processes).
    readonly property var rows: {
        const q = search.text.toLowerCase();
        const list = SystemStats.procsFull.filter(p => {
            if (root.procFilter === 1 && !root.isMine(p.user))
                return false;
            if (root.procFilter === 2 && root.isMine(p.user))
                return false;
            if (q && p.comm.toLowerCase().indexOf(q) < 0 && String(p.pid).indexOf(q) < 0)
                return false;
            return true;
        });
        list.sort((a, b) => root.sortKey === 0 ? b.cpu - a.cpu : b.mem - a.mem);
        return list.slice(0, 100);
    }

    // Persistent model kept in sync in place (never reassigned) so the ListView
    // keeps its scroll position on refresh and can animate reorders. Frozen while
    // the pointer is over the list, so rows don't shuffle out from under it.
    ListModel { id: procModel }
    property bool listFrozen: false

    function syncModel() {
        if (listFrozen)
            return;
        const target = rows;
        const has = {};
        for (const t of target)
            has[t.pid] = true;
        for (let i = procModel.count - 1; i >= 0; i--)
            if (!has[procModel.get(i).pid])
                procModel.remove(i);
        for (let i = 0; i < target.length; i++) {
            const t = target[i];
            const row = {
                "pid": t.pid,
                "user": t.user,
                "comm": t.comm,
                "cpu": t.cpu,
                "mem": t.mem
            };
            let cur = -1;
            for (let j = i; j < procModel.count; j++)
                if (procModel.get(j).pid === t.pid) {
                    cur = j;
                    break;
                }
            if (cur === -1) {
                procModel.insert(i, row);
            } else {
                if (cur !== i)
                    procModel.move(cur, i, 1);
                procModel.set(i, row);
            }
        }
        while (procModel.count > target.length)
            procModel.remove(procModel.count - 1);
    }

    onRowsChanged: syncModel()
    onListFrozenChanged: if (!listFrozen)
        syncModel()

    Timer {
        id: copiedTimer
        interval: 1200
        onTriggered: root.copiedPid = ""
    }

    MIcon {
        id: icon
        anchors.centerIn: parent
        text: "monitoring"
        size: 20
        fill: pop.isOpen
        color: pop.isOpen ? Theme.primary : (SystemStats.cpu > 0.85 ? Theme.urgent : (ma.containsMouse ? Theme.iconHover : Theme.surfaceText))
        scale: ma.containsMouse ? 1.15 : 1.0
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pop.toggle()
    }

    // Quicken polling + run ps only while the panel is open.
    Binding {
        target: SystemStats
        property: "active"
        value: pop.isOpen
    }
    // Poll fan RPM/PWM only while the fan section is open.
    Binding {
        target: Fans
        property: "active"
        value: pop.isOpen && root.fansOpen
    }

    Popout {
        id: pop
        bar: root.bar
        anchorItem: root
        popId: "processes"
        popWidth: 540
        keyboardOnOpen: true

        // Auto-focus the search box when the panel opens, so you can type at once.
        Connections {
            target: pop
            function onIsOpenChanged() {
                if (pop.isOpen)
                    Qt.callLater(() => search.focusInput());
            }
        }

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gap
            MIcon { text: "monitoring"; size: 20; color: Theme.primary }
            Text {
                text: "Processes"
                color: Theme.surfaceText
                font.family: Theme.font
                font.pixelSize: Theme.fontSize + 1
                font.bold: true
                Layout.fillWidth: true
            }
            Text {
                text: root.rows.length + " shown"
                color: Theme.surfaceVariantText
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 2
            }
        }

        // Stats: compact system info (left) beside the gauges (right).
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            Layout.bottomMargin: 2
            spacing: Theme.gapL

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 1
                Text {
                    text: SystemStats.hostname || "localhost"
                    color: Theme.surfaceText
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 2
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: SystemStats.distro
                    color: Theme.surfaceVariantText
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 2
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Item { implicitHeight: 4 }
                Text {
                    text: root.shortCpu(SystemStats.cpuModel)
                    color: Theme.surfaceVariantText
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 2
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    visible: text !== ""
                    text: root.shortGpu(SystemStats.gpuName)
                    color: Theme.surfaceVariantText
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 2
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            CircleGauge {
                id: cpuGauge
                diameter: 92
                value: SystemStats.cpu
                value2: SystemStats.cpuTemp > 0 ? Math.min(1, SystemStats.cpuTemp / 100) : -1
                big: Math.round(SystemStats.cpu * 100) + "%"
                small: SystemStats.cpuTemp > 0 ? (Math.round(SystemStats.cpuTemp) + "°C") : ""
                caption: root.fansOpen ? "Fans ▴" : "CPU"
                arcColor: SystemStats.cpu > 0.85 ? Theme.urgent : Theme.primary
                arcColor2: SystemStats.cpuTemp > 85 ? Theme.urgent : Theme.warn

                // Click the CPU gauge to reveal fan controls.
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.fansOpen = !root.fansOpen
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
                small: SystemStats.gpuTemp > 0 ? (Math.round(SystemStats.gpuTemp) + "°C") : ""
                caption: "GPU"
                arcColor: SystemStats.gpuUsage > 0.85 ? Theme.urgent : Theme.primary
                arcColor2: SystemStats.gpuTemp > 85 ? Theme.urgent : Theme.warn
            }
        }

        // Fan control — revealed by clicking the CPU gauge.
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.fansOpen
            spacing: Theme.gap

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.gap
                MIcon { text: "mode_fan"; size: 18; color: Theme.primary }
                Text {
                    text: "Fan control"
                    color: Theme.surfaceText
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                    Layout.fillWidth: true
                }
            }
            Text {
                visible: !Fans.available
                Layout.fillWidth: true
                text: "No controllable fans detected — load the nct6775 module and the PWM udev rule."
                color: Theme.surfaceVariantText
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 2
                wrapMode: Text.WordWrap
            }
            Repeater {
                model: Fans.fans
                delegate: RowLayout {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    spacing: Theme.gap
                    Text {
                        text: "Fan " + (index + 1)
                        color: Theme.surfaceText
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        Layout.preferredWidth: 44
                    }
                    Text {
                        text: modelData.rpm + " rpm"
                        color: Theme.surfaceVariantText
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 2
                        Layout.preferredWidth: 66
                    }
                    MSlider {
                        Layout.fillWidth: true
                        value: modelData.pct / 100
                        onMoved: v => Fans.setPct(modelData.idx, v * 100)
                    }
                    MButton {
                        Layout.preferredWidth: 68
                        label: modelData.manual ? "Manual" : "Auto"
                        filled: modelData.manual
                        onClicked: Fans.setManual(modelData.idx, !modelData.manual)
                    }
                }
            }
        }

        // Filter + search
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gap
            MButton { label: "All"; filled: root.procFilter === 0; onClicked: root.procFilter = 0 }
            MButton { label: "Mine"; filled: root.procFilter === 1; onClicked: root.procFilter = 1 }
            MButton { label: "System"; filled: root.procFilter === 2; onClicked: root.procFilter = 2 }
            MTextField {
                id: search
                Layout.fillWidth: true
                icon: "search"
                placeholder: "Search"
            }
        }

        // Column header — CPU / MEM are clickable to sort (▾ marks the active key).
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gap
            Text { text: "Process"; color: Theme.surfaceVariantText; font.family: Theme.font; font.pixelSize: Theme.fontSize - 3; Layout.fillWidth: true }
            SortHeader { label: "CPU"; key: 0 }
            SortHeader { label: "MEM"; key: 1 }
            Item { implicitWidth: 24 }
        }

        // Process list — persistent model updated in place (keeps scroll on
        // refresh); reorders slide via the move/displaced transitions.
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.preferredHeight: 280
            clip: true
            model: procModel
            boundsBehavior: Flickable.StopAtBounds
            spacing: 1
            cacheBuffer: 400

            HoverHandler { onHoveredChanged: root.listFrozen = hovered }

            add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durShort } }
            remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: Theme.durShort } }
            move: Transition { NumberAnimation { property: "y"; duration: Theme.durMed; easing.type: Easing.OutCubic } }
            displaced: Transition { NumberAnimation { property: "y"; duration: Theme.durMed; easing.type: Easing.OutCubic } }

            delegate: Rectangle {
                id: row
                required property string pid
                required property string comm
                required property real cpu
                required property real mem
                readonly property bool copied: root.copiedPid === pid
                // HoverHandler reports hover across the whole row — including over
                // the kill icon — so the highlight stays put and consistent.
                readonly property bool hovered: rowHover.hovered

                width: ListView.view.width
                implicitHeight: 26
                radius: Theme.radiusS
                // Base is the opaque panel surface (NOT "transparent"): animating a
                // colour to transparent interpolates through semi-transparent black,
                // which flashed dark when leaving hover.
                color: row.copied ? Theme.surfaceContainerHigh : row.hovered ? Theme.surfaceContainer : Theme.surface
                Behavior on color { ColorAnimation { duration: 110 } }

                HoverHandler { id: rowHover }

                // Click the row (anywhere but the kill icon) to copy the PID.
                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached(["wl-copy", "--", row.pid]);
                        root.copiedPid = row.pid;
                        copiedTimer.restart();
                    }
                }

                RowLayout {
                    anchors { fill: parent; leftMargin: 6; rightMargin: 4 }
                    spacing: Theme.gap
                    Text {
                        text: row.comm
                        color: Theme.surfaceText
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: row.copied ? "copied ✓" : "#" + row.pid
                        color: row.copied ? Theme.primary : Theme.surfaceVariantText
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 3
                        visible: row.hovered || row.copied
                    }
                    Text {
                        text: row.cpu.toFixed(0) + "%"
                        color: row.cpu > 50 ? Theme.warn : Theme.surfaceText
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 1
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: 52
                    }
                    Text {
                        text: row.mem.toFixed(0) + "%"
                        color: Theme.surfaceVariantText
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 1
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: 52
                    }
                    // Kill icon — no background of its own (keeps the row's single
                    // highlight consistent); just brightens to red on direct hover.
                    MIcon {
                        text: "close"
                        size: 15
                        Layout.preferredWidth: 24
                        horizontalAlignment: Text.AlignHCenter
                        color: killMa.containsMouse ? Theme.urgent : Theme.surfaceVariantText
                        opacity: row.hovered ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 110 } }
                        MouseArea {
                            id: killMa
                            anchors.fill: parent
                            anchors.margins: -3
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: SystemStats.killProcess(row.pid)
                        }
                    }
                }
            }
        }
    }
}
