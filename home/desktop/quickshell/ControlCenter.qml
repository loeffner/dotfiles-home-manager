// ControlCenter — the right-cluster "quick settings" pill + popout. The bar pill
// shows live network / bluetooth / volume / mic status; the popout has a
// power/lock/settings header, audio output+input sliders, expandable Wi-Fi and
// Bluetooth tiles, and a Do-Not-Disturb toggle. Reuses the same services as the
// standalone Audio/Network widgets (Pipewire, Quickshell.Networking) plus
// Quickshell.Bluetooth. Battery/brightness are omitted (terra is a desktop).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Wayland

Item {
    id: root
    required property var bar

    implicitWidth: pill.implicitWidth
    implicitHeight: Theme.barHeight

    // ── Audio ────────────────────────────────────────────────────────────────
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property real vol: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real micVol: source?.audio?.volume ?? 0
    readonly property bool micMuted: source?.audio?.muted ?? false
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }
    function setVol(v) {
        if (sink?.audio)
            sink.audio.volume = Math.max(0, Math.min(1, v));
    }
    function setMic(v) {
        if (source?.audio)
            source.audio.volume = Math.max(0, Math.min(1, v));
    }
    function volIcon(v, m) {
        return m || v <= 0 ? "volume_off" : v < 0.34 ? "volume_mute" : v < 0.67 ? "volume_down" : "volume_up";
    }
    readonly property var outputs: (Pipewire.nodes?.values ?? []).filter(n => n && n.audio && n.isSink && !n.isStream)
    readonly property var inputs: (Pipewire.nodes?.values ?? []).filter(n => n && n.audio && !n.isSink && !n.isStream)
    function devName(n) {
        return n ? (n.description || n.nickname || n.name || "Unknown") : "";
    }
    // A fitting Material Symbol for a device, inferred from its name.
    function devIcon(n, output) {
        const s = root.devName(n).toLowerCase();
        if (s.includes("webcam") || s.includes("camera"))
            return "videocam";
        if (s.includes("head") || s.includes("earbud") || s.includes("airpod"))
            return "headphones";
        if (s.includes("hdmi") || s.includes("display") || s.includes("tv"))
            return "tv";
        if (s.includes("soundbar") || s.includes("speaker"))
            return "speaker";
        if (!output && (s.includes("mic") || s.includes("blue")))
            return "mic";
        return output ? "speaker" : "mic";
    }
    // Track all nodes so their audio metadata (needed by the filters above) is
    // populated even for the non-default devices.
    PwObjectTracker {
        objects: Pipewire.nodes ? Pipewire.nodes.values : []
    }

    // The device list under a slider (unfolded by the slider's chevron). Stays
    // open when you pick a device (so you can see the selection move).
    component DevicePicker: ColumnLayout {
        id: dp
        property string key: ""
        property var current: null
        property var list: []
        property bool isOutput: true
        signal picked(var node)
        Layout.fillWidth: true
        Layout.leftMargin: 30
        Layout.topMargin: root.expanded === dp.key ? 2 : 0
        spacing: 2
        Repeater {
            model: root.expanded === dp.key ? dp.list : []
            delegate: Rectangle {
                id: devRow
                required property var modelData
                readonly property bool sel: modelData === dp.current
                Layout.fillWidth: true
                implicitHeight: 36
                radius: Theme.radiusM
                color: devRow.sel ? Theme.surfaceContainerHigh : (dma.containsMouse ? Theme.surfaceContainer : Theme.surface)
                Behavior on color { ColorAnimation { duration: 110 } }

                RowLayout {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 10 }
                    spacing: Theme.gap
                    Rectangle {
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: width / 2
                        color: devRow.sel ? Theme.primary : Theme.surfaceContainerHigh
                        MIcon {
                            anchors.centerIn: parent
                            text: root.devIcon(devRow.modelData, dp.isOutput)
                            size: 15
                            color: devRow.sel ? Theme.primaryText : Theme.surfaceVariantText
                        }
                    }
                    Text {
                        text: root.devName(devRow.modelData)
                        color: devRow.sel ? Theme.primary : Theme.surfaceText
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        font.bold: devRow.sel
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    MIcon {
                        visible: devRow.sel
                        text: "check_circle"
                        fill: true
                        size: 16
                        color: Theme.primary
                    }
                }
                MouseArea {
                    id: dma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: dp.picked(devRow.modelData) // keep the list open
                }
            }
        }
    }

    // ── Network ──────────────────────────────────────────────────────────────
    readonly property var netDevices: Networking.devices?.values ?? []
    readonly property var activeDev: netDevices.find(d => d.connected) ?? null
    readonly property bool online: activeDev !== null
    readonly property var wifiDev: netDevices.find(d => d.scannerEnabled !== undefined) ?? null
    readonly property bool activeIsWifi: activeDev ? (activeDev.scannerEnabled !== undefined) : false
    // Wired device: a managed device that isn't the Wi-Fi radio (no scanner).
    readonly property var ethDev: netDevices.find(d => d.scannerEnabled === undefined) ?? null
    // Connected when the active link is wired (matches the pill's lan icon), or a
    // wired device itself reports connected.
    readonly property bool ethConnected: (root.online && !root.activeIsWifi) || (root.ethDev?.connected ?? false)
    // The connected network's SSID (not the device name).
    readonly property string connectedSsid: {
        const n = (root.wifiDev?.networks?.values ?? []).find(x => x.connected);
        return n ? (n.name || "") : "";
    }
    function netIcon() {
        if (!online)
            return "signal_wifi_off";
        return activeIsWifi ? "wifi" : "lan";
    }

    // Local + external IP for the Ethernet row. Refreshed whenever the panel
    // opens (external IP needs a network round-trip, so it's not kept live).
    property string localIp: ""
    property string externalIp: ""
    function refreshIps() {
        localIpProc.running = true;
        externalIp = "";
        extIpProc.running = true;
    }
    Process {
        id: localIpProc
        // The src address of the default route = the IP actually used to reach the
        // internet, regardless of interface name.
        command: ["sh", "-c", "ip -4 route get 1.1.1.1 2>/dev/null | grep -oP 'src \\K[0-9.]+' | head -1"]
        stdout: StdioCollector {
            onStreamFinished: root.localIp = text.trim()
        }
    }
    Process {
        id: extIpProc
        command: ["sh", "-c", "curl -s --max-time 4 https://api.ipify.org"]
        stdout: StdioCollector {
            onStreamFinished: root.externalIp = text.trim()
        }
    }
    // Wi-Fi passphrase state, hoisted so a rescan rebuild of the delegates doesn't
    // wipe the field being typed into.
    property string pskSsid: ""
    property string pskText: ""

    // ── Bluetooth ────────────────────────────────────────────────────────────
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btOn: btAdapter?.enabled ?? false
    readonly property var btDevices: btAdapter?.devices?.values ?? []
    readonly property var btConnected: btDevices.filter(d => d.connected)

    // Expansion state for the tiles (only one open at a time).
    property string expanded: "" // "wifi" | "bt" | ""

    // Pending reboot/power-off confirmation.
    property string confirmAction: "" // "reboot" | "poweroff"
    function confirm(action) {
        confirmAction = action;
        confirmPop.open();
    }
    function doConfirm() {
        if (confirmAction)
            Quickshell.execDetached(["systemctl", confirmAction]);
        confirmPop.close();
    }

    // ── Bar pill ─────────────────────────────────────────────────────────────
    Row {
        id: pill
        anchors.centerIn: parent
        spacing: 5
        // On hover the whole pill picks up the accent so it reads as one control.
        readonly property bool hov: pop.isOpen || ma.containsMouse
        scale: ma.containsMouse ? 1.12 : 1.0
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        MIcon {
            text: root.netIcon()
            size: 18
            color: pill.hov ? Theme.iconHover : (root.online ? Theme.surfaceText : Theme.surfaceVariantText)
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        MIcon {
            text: root.btConnected.length > 0 ? "bluetooth_connected" : (root.btOn ? "bluetooth" : "bluetooth_disabled")
            size: 18
            color: pill.hov ? Theme.iconHover : (root.btConnected.length > 0 ? Theme.primary : (root.btOn ? Theme.surfaceText : Theme.surfaceVariantText))
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        MIcon {
            text: root.volIcon(root.vol, root.muted)
            size: 18
            color: pill.hov ? Theme.iconHover : (root.muted ? Theme.surfaceVariantText : Theme.surfaceText)
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        MIcon {
            visible: root.micMuted
            text: "mic_off"
            size: 18
            color: Theme.urgent
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pop.toggle()
    }

    // Scan while the Wi-Fi list is expanded. (Disabling the scanner empties the
    // network list, so we keep scanning and instead FREEZE the displayed list
    // while a passphrase is being typed — see wifiList below — so the delegates
    // don't rebuild and steal focus from the field.)
    function syncScanner() {
        if (root.wifiDev)
            root.wifiDev.scannerEnabled = pop.isOpen && root.expanded === "wifi";
    }
    Connections {
        target: pop
        function onIsOpenChanged() {
            if (!pop.isOpen) {
                root.expanded = "";
                root.pskSsid = "";
            } else if (root.ethConnected) {
                root.refreshIps();
            }
            root.syncScanner();
        }
    }
    onExpandedChanged: {
        if (root.expanded !== "wifi")
            root.pskSsid = ""; // collapsing the tile also cancels passphrase entry
        root.syncScanner();
    }

    // Live (sorted) network list; wifiList mirrors it EXCEPT while a passphrase is
    // open, so the Repeater delegates stay put and keep the field's focus.
    readonly property var wifiListLive: {
        if (root.expanded !== "wifi" || !root.wifiDev)
            return [];
        const nets = (root.wifiDev.networks?.values ?? []).slice();
        nets.sort((a, b) => (b.connected - a.connected) || ((b.signalStrength ?? 0) - (a.signalStrength ?? 0)));
        return nets;
    }
    property var wifiList: []
    onWifiListLiveChanged: if (root.pskSsid === "")
        root.wifiList = wifiListLive
    onPskSsidChanged: if (root.pskSsid === "")
        root.wifiList = wifiListLive

    // ── Popout ───────────────────────────────────────────────────────────────
    Popout {
        id: pop
        bar: root.bar
        anchorItem: root
        popId: "control"
        popWidth: 420
        keyboardOnOpen: true

        // Header — title + round session buttons (Suspend / Reboot / Power Off).
        // Full-width, above the controls/rail split so the accent rail lines up
        // with the volume control rather than the header.
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gap
            Text {
                text: "Controls"
                color: Theme.surfaceText
                font.family: Theme.font
                font.pixelSize: Theme.fontSize + 1
                font.bold: true
                Layout.fillWidth: true
            }
            MIconButton {
                icon: "lock" // lock the session (swaylock daemonizes itself)
                raised: true
                onClicked: {
                    Quickshell.execDetached(["swaylock"]);
                    pop.close();
                }
            }
            MIconButton {
                icon: "bedtime" // sleep / suspend (moon)
                raised: true
                onClicked: {
                    Quickshell.execDetached(["systemctl", "suspend"]);
                    pop.close();
                }
            }
            MIconButton {
                icon: "refresh" // reboot (round arrow)
                raised: true
                onClicked: root.confirm("reboot")
            }
            MIconButton {
                icon: "power_settings_new"
                raised: true
                activeColor: Theme.urgent
                onClicked: root.confirm("poweroff")
            }
        }

        // Body: controls column + vertical accent/background rail on the right.
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gapL

            ColumnLayout {
                id: ccMain
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: Theme.gapL

                // Audio output + input sliders.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.gap
                    MIconButton {
                        icon: root.volIcon(root.vol, root.muted)
                        active: root.muted
                        onClicked: if (root.sink?.audio)
                            root.sink.audio.muted = !root.sink.audio.muted
                    }
                    MSlider {
                        Layout.fillWidth: true
                        value: root.vol
                        onMoved: v => root.setVol(v)
                    }
                    Text {
                        text: Math.round(root.vol * 100) + "%"
                        color: Theme.surfaceVariantText
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 1
                        Layout.preferredWidth: 34
                        horizontalAlignment: Text.AlignRight
                    }
                    MIcon {
                        text: "expand_more"
                        size: 18
                        rotation: root.expanded === "out" ? 180 : 0
                        color: Theme.surfaceVariantText
                        Behavior on rotation { NumberAnimation { duration: 150 } }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.expanded = root.expanded === "out" ? "" : "out"
                        }
                    }
                }
                DevicePicker {
                    key: "out"
                    current: root.sink
                    list: root.outputs
                    onPicked: node => Pipewire.preferredDefaultAudioSink = node
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.gap
                    MIconButton {
                        icon: root.micMuted ? "mic_off" : "mic"
                        active: root.micMuted
                        onClicked: if (root.source?.audio)
                            root.source.audio.muted = !root.source.audio.muted
                    }
                    MSlider {
                        Layout.fillWidth: true
                        value: root.micVol
                        onMoved: v => root.setMic(v)
                    }
                    Text {
                        text: Math.round(root.micVol * 100) + "%"
                        color: Theme.surfaceVariantText
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 1
                        Layout.preferredWidth: 34
                        horizontalAlignment: Text.AlignRight
                    }
                    MIcon {
                        text: "expand_more"
                        size: 18
                        rotation: root.expanded === "in" ? 180 : 0
                        color: Theme.surfaceVariantText
                        Behavior on rotation { NumberAnimation { duration: 150 } }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.expanded = root.expanded === "in" ? "" : "in"
                        }
                    }
                }
                DevicePicker {
                    key: "in"
                    isOutput: false
                    current: root.source
                    list: root.inputs
                    onPicked: node => Pipewire.preferredDefaultAudioSource = node
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.outline; opacity: 0.4 }

                // ── Ethernet (indicator only, not toggleable) ────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    visible: root.ethDev !== null
                    spacing: Theme.gap
                    MIcon {
                        text: "lan"
                        size: 20
                        color: root.ethConnected ? Theme.primary : Theme.surfaceVariantText
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            text: "Ethernet"
                            color: Theme.surfaceText
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                        }
                        Text {
                            text: root.ethConnected ? "Connected" : "Not connected"
                            color: Theme.surfaceVariantText
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 3
                        }
                        // Local + external IP (shown while connected).
                        Text {
                            visible: root.ethConnected
                            text: "Local " + (root.localIp || "…")
                            color: Theme.surfaceVariantText
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 3
                        }
                        Text {
                            visible: root.ethConnected
                            text: "External " + (root.externalIp || "…")
                            color: Theme.surfaceVariantText
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize - 3
                        }
                    }
                    // Connection status dot.
                    Rectangle {
                        implicitWidth: 8
                        implicitHeight: 8
                        radius: 4
                        color: root.ethConnected ? Theme.good : Theme.surfaceVariantText
                    }
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.outline; opacity: 0.4; visible: root.ethDev !== null }

                // ── Wi-Fi tile ─────────────────────────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.wifiDev !== null
                    spacing: Theme.gap

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.gap
                        // Left region: left-click expands, right-click opens Wi-Fi settings.
                        Item {
                            Layout.fillWidth: true
                            implicitHeight: wHdr.implicitHeight
                            RowLayout {
                                id: wHdr
                                anchors.fill: parent
                                spacing: Theme.gap
                                MIcon { text: Networking.wifiEnabled ? "wifi" : "signal_wifi_off"; size: 20; color: Theme.primary }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Text {
                                        text: "Wi-Fi"
                                        color: Theme.surfaceText
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize
                                    }
                                    Text {
                                        text: root.connectedSsid ? root.connectedSsid : (Networking.wifiEnabled ? "Not connected" : "Off")
                                        color: Theme.surfaceVariantText
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize - 3
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: e => {
                                    if (e.button === Qt.RightButton) {
                                        Quickshell.execDetached(["nm-connection-editor"]);
                                        pop.close();
                                    } else {
                                        root.expanded = root.expanded === "wifi" ? "" : "wifi";
                                    }
                                }
                            }
                        }
                        MIcon {
                            text: "expand_more"
                            size: 20
                            rotation: root.expanded === "wifi" ? 180 : 0
                            color: Theme.surfaceVariantText
                            Behavior on rotation { NumberAnimation { duration: 150 } }
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.expanded = root.expanded === "wifi" ? "" : "wifi"
                            }
                        }
                        MToggle {
                            checked: Networking.wifiEnabled
                            onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                        }
                    }

                    // Network list (only when expanded); frozen during passphrase entry.
                    Repeater {
                        model: root.wifiList
                        delegate: ColumnLayout {
                            id: netRow
                            required property var modelData
                            readonly property bool secured: modelData.security !== WifiSecurityType.Open
                            readonly property bool expanded: root.pskSsid === modelData.name
                            Layout.fillWidth: true
                            Layout.leftMargin: 8
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Theme.gap
                                MIcon {
                                    text: {
                                        const s = netRow.modelData.signalStrength ?? 0;
                                        return s > 0.75 ? "signal_wifi_4_bar" : s > 0.4 ? "network_wifi_3_bar" : "network_wifi_1_bar";
                                    }
                                    size: 16
                                    color: netRow.modelData.connected ? Theme.primary : Theme.surfaceVariantText
                                }
                                Text {
                                    text: netRow.modelData.name || "(hidden)"
                                    color: netRow.modelData.connected ? Theme.primary : Theme.surfaceText
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize
                                    font.bold: netRow.modelData.connected
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                MIcon {
                                    visible: netRow.secured
                                    text: "lock"
                                    size: 13
                                    color: Theme.surfaceVariantText
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        const n = netRow.modelData;
                                        if (n.connected)
                                            n.disconnect();
                                        else if (n.known || !netRow.secured)
                                            n.connect();
                                        else if (netRow.expanded)
                                            root.pskSsid = "";
                                        else {
                                            root.pskSsid = n.name;
                                            root.pskText = "";
                                        }
                                    }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                visible: netRow.expanded
                                spacing: Theme.gap
                                MTextField {
                                    id: psk
                                    Layout.fillWidth: true
                                    icon: "password"
                                    placeholder: "Passphrase"
                                    password: true
                                    // Seed from the hoisted text so a rescan-driven rebuild
                                    // restores what was typed; write edits back.
                                    Component.onCompleted: {
                                        text = root.pskText;
                                        Qt.callLater(() => psk.focusInput());
                                    }
                                    onTextChanged: root.pskText = text
                                    onAccepted: {
                                        netRow.modelData.connectWithPsk(psk.text);
                                        root.pskSsid = "";
                                    }
                                    onCanceled: root.pskSsid = "" // Escape cancels
                                }
                                MIconButton {
                                    icon: "close"
                                    raised: true
                                    onClicked: root.pskSsid = ""
                                }
                                MButton {
                                    label: "Join"
                                    filled: true
                                    onClicked: {
                                        netRow.modelData.connectWithPsk(psk.text);
                                        root.pskSsid = "";
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.outline; opacity: 0.4; visible: root.wifiDev !== null }

                // ── Bluetooth tile ─────────────────────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.btAdapter !== null
                    spacing: Theme.gap

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.gap
                        Item {
                            Layout.fillWidth: true
                            implicitHeight: bHdr.implicitHeight
                            RowLayout {
                                id: bHdr
                                anchors.fill: parent
                                spacing: Theme.gap
                                MIcon {
                                    text: root.btConnected.length > 0 ? "bluetooth_connected" : "bluetooth"
                                    size: 20
                                    color: Theme.primary
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0
                                    Text {
                                        text: "Bluetooth"
                                        color: Theme.surfaceText
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize
                                    }
                                    Text {
                                        text: !root.btOn ? "Off" : (root.btConnected.length > 0 ? root.btConnected.map(d => d.name).join(", ") : "No devices")
                                        color: Theme.surfaceVariantText
                                        font.family: Theme.font
                                        font.pixelSize: Theme.fontSize - 3
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: e => {
                                    if (e.button === Qt.RightButton) {
                                        Quickshell.execDetached(["blueman-manager"]);
                                        pop.close();
                                    } else {
                                        root.expanded = root.expanded === "bt" ? "" : "bt";
                                        if (root.btAdapter)
                                            root.btAdapter.discovering = (root.expanded === "bt" && root.btOn);
                                    }
                                }
                            }
                        }
                        MIcon {
                            text: "expand_more"
                            size: 20
                            rotation: root.expanded === "bt" ? 180 : 0
                            color: Theme.surfaceVariantText
                            Behavior on rotation { NumberAnimation { duration: 150 } }
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.expanded = root.expanded === "bt" ? "" : "bt";
                                    if (root.btAdapter)
                                        root.btAdapter.discovering = (root.expanded === "bt" && root.btOn);
                                }
                            }
                        }
                        MToggle {
                            checked: root.btOn
                            onToggled: if (root.btAdapter)
                                root.btAdapter.enabled = !root.btAdapter.enabled
                        }
                    }

                    Repeater {
                        model: root.expanded === "bt" ? root.btDevices : []
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.leftMargin: 8
                            spacing: Theme.gap
                            MIcon {
                                text: modelData.connected ? "bluetooth_connected" : "bluetooth"
                                size: 16
                                color: modelData.connected ? Theme.primary : Theme.surfaceVariantText
                            }
                            Text {
                                text: modelData.name || modelData.address
                                color: modelData.connected ? Theme.primary : Theme.surfaceText
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                visible: modelData.pairing || modelData.connected && modelData.batteryAvailable
                                text: modelData.pairing ? "pairing…" : (modelData.batteryAvailable ? Math.round(modelData.battery * 100) + "%" : "")
                                color: Theme.surfaceVariantText
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize - 2
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const d = modelData;
                                    if (d.connected)
                                        d.disconnect();
                                    else if (d.paired || d.bonded)
                                        d.connect();
                                    else
                                        d.pair();
                                }
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.outline; opacity: 0.4; visible: root.btAdapter !== null }

                // ── Do Not Disturb ──────────────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.gap
                    MIcon {
                        text: Notifications.dnd ? "do_not_disturb_on" : "do_not_disturb_off"
                        size: 20
                        color: Notifications.dnd ? Theme.primary : Theme.surfaceVariantText
                    }
                    Text {
                        text: "Do Not Disturb"
                        color: Theme.surfaceText
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        Layout.fillWidth: true
                    }
                    MToggle {
                        checked: Notifications.dnd
                        onToggled: Notifications.dnd = !Notifications.dnd
                    }
                }

            } // end main column (ccMain)

            // ── Accent rail ───────────────────────────────────────────────────────
            // Vertical swatch bar; each sets Theme.primary shell-wide (persisted via
            // Theme.setAccent). Pinned to the top-right of the popout.
            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                spacing: Theme.gap

                Repeater {
                    model: Theme.accentOrder
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool sel: Theme.accentChoice === modelData
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: width / 2
                        color: Theme.accents[modelData]
                        border.width: sel ? 2 : 0
                        border.color: Theme.surfaceText
                        scale: swatchMa.containsMouse ? 1.14 : 1
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuart } }

                        MIcon {
                            anchors.centerIn: parent
                            visible: parent.sel
                            text: "check"
                            size: 15
                            fill: true
                            color: (0.299 * parent.color.r + 0.587 * parent.color.g + 0.114 * parent.color.b) > 0.5 ? "#1d2021" : "#fbf1c7"
                        }

                        MouseArea {
                            id: swatchMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Theme.setAccent(modelData)
                        }
                    }
                }

                // Divider between accent hues and background presets.
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 20
                    implicitHeight: 1
                    color: Theme.outline
                    opacity: 0.5
                }

                // Background presets — the surface ramp (medium / hard / soft).
                Repeater {
                    model: Theme.bgOrder
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool sel: Theme.bgChoice === modelData
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: Theme.radiusS
                        color: Theme.backgrounds[modelData].surface
                        border.width: sel ? 2 : 1
                        border.color: sel ? Theme.primary : Theme.outline
                        scale: bgMa.containsMouse ? 1.14 : 1
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuart } }

                        // Corner chip hinting the preset's lightest step.
                        Rectangle {
                            anchors { right: parent.right; bottom: parent.bottom; margins: 4 }
                            width: 8
                            height: 8
                            radius: 2
                            color: Theme.backgrounds[modelData].highest
                        }

                        MouseArea {
                            id: bgMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Theme.setBackground(modelData)
                        }
                    }
                }
            }
        } // end main-column + rail RowLayout
    }

    // ── Reboot / Power-off confirmation ──────────────────────────────────────
    Popout {
        id: confirmPop
        bar: root.bar
        anchorItem: root
        popId: "ccconfirm"
        popWidth: 260
        keyboardOnOpen: true

        Item {
            id: keyCatcher
            Layout.fillWidth: true
            implicitHeight: 0
            focus: true
            Keys.onReturnPressed: root.doConfirm()
            Keys.onEnterPressed: root.doConfirm()
            Keys.onEscapePressed: confirmPop.close()
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gap
            MIcon {
                text: root.confirmAction === "reboot" ? "restart_alt" : "power_settings_new"
                size: 22
                color: Theme.urgent
            }
            Text {
                text: root.confirmAction === "reboot" ? "Reboot now?" : "Power off now?"
                color: Theme.surfaceText
                font.family: Theme.font
                font.pixelSize: Theme.fontSize + 1
                font.bold: true
                Layout.fillWidth: true
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gap
            MButton {
                Layout.fillWidth: true
                label: "Cancel"
                onClicked: confirmPop.close()
            }
            MButton {
                Layout.fillWidth: true
                filled: true
                label: root.confirmAction === "reboot" ? "Reboot" : "Power off"
                onClicked: root.doConfirm()
            }
        }
        Text {
            Layout.fillWidth: true
            text: "Enter to confirm · Esc to cancel"
            color: Theme.surfaceVariantText
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 3
            horizontalAlignment: Text.AlignHCenter
        }
    }

    Connections {
        target: confirmPop
        function onIsOpenChanged() {
            if (confirmPop.isOpen)
                Qt.callLater(() => keyCatcher.forceActiveFocus());
            else
                root.confirmAction = "";
        }
    }

    // ── Transient volume / mic OSD ───────────────────────────────────────────
    // A card under the pill matching the Control Center's volume row (same x /
    // width / styling / spot), shown on volume or mic changes and auto-hidden.
    // Suppressed while the full popout is open (it already shows the slider).
    property string osdMode: "volume"
    property bool _osdAlive: false
    property real osdMonitorVol: sink?.audio?.volume ?? -1
    property bool _osdPrimed: false
    readonly property int osdW: 380
    readonly property real osdX: {
        if (!root.bar)
            return 8;
        const c = root.mapToItem(root.bar.contentItem, 0, 0).x + root.width / 2 - osdW / 2;
        return Math.max(8, Math.min(c, root.bar.width - osdW - 8));
    }
    function showOsd(m) {
        if (pop.isOpen)
            return; // the popout already shows the volume slider
        osdMode = m;
        _osdAlive = true;
        osdHideTimer.restart();
    }
    onOsdMonitorVolChanged: {
        if (osdMonitorVol < 0)
            return;
        if (!_osdPrimed) {
            _osdPrimed = true;
            return;
        }
        showOsd("volume");
    }
    Connections {
        target: root.source?.audio ?? null
        function onMutedChanged() { root.showOsd("mic"); }
    }
    Timer {
        id: osdHideTimer
        interval: 1500
        onTriggered: root._osdAlive = false
    }

    PanelWindow {
        id: osdWin
        screen: root.bar ? root.bar.screen : null
        anchors { top: true; left: true }
        // Offset so the volume row lands at the same y as inside the popout
        // (below its header). Card padding then aligns the slider exactly.
        margins { top: Theme.barHeight + 46; left: root.osdX }
        implicitWidth: root.osdW
        implicitHeight: osdRow.implicitHeight + Theme.padL * 2
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        visible: root._osdAlive || osdCard.opacity > 0
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        // Click-through: the OSD is feedback, not a control.
        mask: Region { item: osdMaskItem }
        Item { id: osdMaskItem; width: 0; height: 0 }

        Rectangle {
            id: osdCard
            anchors.fill: parent
            radius: Theme.radiusL
            color: Theme.surface
            border.width: 1
            border.color: Theme.outline
            opacity: root._osdAlive ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

            RowLayout {
                id: osdRow
                anchors { fill: parent; margins: Theme.padL }
                spacing: Theme.gap
                MIcon {
                    text: root.osdMode === "mic" ? (root.micMuted ? "mic_off" : "mic") : root.volIcon(root.vol, root.muted)
                    size: 20
                    Layout.preferredWidth: 32
                    horizontalAlignment: Text.AlignHCenter
                    color: (root.osdMode === "mic" ? root.micMuted : root.muted) ? Theme.surfaceVariantText : Theme.surfaceText
                }
                MSlider {
                    Layout.fillWidth: true
                    value: root.osdMode === "mic" ? root.micVol : root.vol
                }
                Text {
                    text: Math.round((root.osdMode === "mic" ? root.micVol : root.vol) * 100) + "%"
                    color: Theme.surfaceVariantText
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 1
                    Layout.preferredWidth: 34
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
}
