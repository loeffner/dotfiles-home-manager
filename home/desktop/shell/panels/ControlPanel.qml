// Control panel ("control"): session buttons (lock / suspend / reboot / power
// off — the last two via the confirm panel), output + input volume with device
// pickers, Ethernet status with local / external IP, Wi-Fi (expandable list,
// passphrase entry) and Bluetooth (expandable device list) tiles, Do Not
// Disturb, and the accent / background rail. Battery and brightness are omitted
// (terra is a desktop).
import QtQuick
import QtQuick.Layouts
import Quickshell.Networking as QsNet
import qs.config
import qs.components
import qs.island
import qs.services

IslandPanel {
    id: root
    panelId: "control"
    panelWidth: 420

    // Which section is expanded: "out" | "in" | "wifi" | "bt" | "" (one at a time).
    property string expanded: ""
    // Wi-Fi passphrase entry, hoisted so a rescan rebuild doesn't wipe the field.
    property string pskSsid: ""
    property string pskText: ""

    onOpened: {
        if (Network.ethConnected)
            Network.refreshIps();
    }
    onClosed: expanded = ""
    onExpandedChanged: {
        if (expanded !== "wifi")
            pskSsid = "";
        else if (pskSsid === "")
            wifiList = Network.wifiNetworks;
        Network.setScanning(isOpen && expanded === "wifi");
        Bluetooth.setDiscovering(isOpen && expanded === "bt");
    }
    onPskSsidChanged: {
        pskText = "";
        if (pskSsid === "")
            wifiList = Network.wifiNetworks;
    }
    // The shown network list mirrors the live one EXCEPT during passphrase entry,
    // so the delegates stay put and keep the field's focus.
    property var wifiList: []
    Connections {
        target: Network
        function onWifiNetworksChanged() {
            if (root.pskSsid === "")
                root.wifiList = Network.wifiNetworks;
        }
    }

    function toggleSection(key) {
        expanded = expanded === key ? "" : key;
    }
    function requestPower(action) {
        Session.request(action);
        Popouts.open(screen, "confirm", Popouts.anchorOf(screen));
    }

    // ── Device picker (unfolds under a volume slider) ────────────────────────
    component DevicePicker: ColumnLayout {
        id: dp
        property string key: ""
        property var current: null
        property var devices: []
        property bool isOutput: true
        signal picked(var node)
        Layout.fillWidth: true
        Layout.leftMargin: 30
        Layout.topMargin: root.expanded === key ? 2 : 0
        spacing: 2
        Repeater {
            model: root.expanded === dp.key ? dp.devices : []
            delegate: ListRow {
                id: devRow
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 36
                radius: Theme.radiusM
                selected: modelData === dp.current
                onClicked: dp.picked(modelData) // keep the list open

                RowLayout {
                    anchors { fill: parent; leftMargin: 8; rightMargin: 10 }
                    spacing: Theme.gap
                    Rectangle {
                        implicitWidth: 26
                        implicitHeight: 26
                        radius: width / 2
                        color: devRow.selected ? Theme.primary : Theme.surfaceContainerHigh
                        MIcon {
                            anchors.centerIn: parent
                            text: Audio.deviceIcon(devRow.modelData, dp.isOutput)
                            size: 15
                            color: devRow.selected ? Theme.primaryText : Theme.surfaceVariantText
                        }
                    }
                    MText {
                        text: Audio.deviceName(devRow.modelData)
                        color: devRow.selected ? Theme.primary : Theme.surfaceText
                        font.bold: devRow.selected
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    MIcon {
                        visible: devRow.selected
                        text: "check_circle"
                        fill: true
                        size: 16
                        color: Theme.primary
                    }
                }
            }
        }
    }

    // ── Volume row (mute button · slider · percent · picker chevron) ──────────
    component VolumeRow: RowLayout {
        property string key: ""
        property string icon: ""
        property bool muted: false
        property real value: 0
        signal toggleMute
        signal moved(real v)
        Layout.fillWidth: true
        spacing: Theme.gap
        MIconButton {
            icon: parent.icon
            active: parent.muted
            onClicked: parent.toggleMute()
        }
        MSlider {
            Layout.fillWidth: true
            value: parent.value
            onMoved: v => parent.moved(v)
        }
        MText {
            text: Math.round(parent.value * 100) + "%"
            muted: true
            sizeDelta: -1
            Layout.preferredWidth: 34
            horizontalAlignment: Text.AlignRight
        }
        Chevron {
            expanded: root.expanded === parent.key
            onClicked: root.toggleSection(parent.key)
        }
    }

    // ── Expandable tile header (icon · title/subtitle · chevron · toggle) ─────
    // Left-click on the label expands, right-click runs `onSecondary` (the
    // advanced settings app).
    component TileHeader: RowLayout {
        id: th
        property string key: ""
        property string icon: ""
        property string title: ""
        property string subtitle: ""
        property bool checked: false
        signal toggled
        signal secondary
        Layout.fillWidth: true
        spacing: Theme.gap
        Item {
            Layout.fillWidth: true
            implicitHeight: labelRow.implicitHeight
            RowLayout {
                id: labelRow
                anchors.fill: parent
                spacing: Theme.gap
                MIcon { text: th.icon; size: 20; color: Theme.primary }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    MText { text: th.title }
                    MText { text: th.subtitle; muted: true; sizeDelta: -3; elide: Text.ElideRight; Layout.fillWidth: true }
                }
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: e => e.button === Qt.RightButton ? th.secondary() : root.toggleSection(th.key)
            }
        }
        Chevron {
            size: 20
            expanded: root.expanded === th.key
            onClicked: root.toggleSection(th.key)
        }
        MToggle {
            checked: th.checked
            onToggled: th.toggled()
        }
    }

    // ── Header ───────────────────────────────────────────────────────────────
    PanelHeader {
        title: "Controls"
        MIconButton {
            icon: "lock"
            raised: true
            onClicked: {
                Session.lock();
                root.close();
            }
        }
        MIconButton {
            icon: "bedtime"
            raised: true
            onClicked: {
                Session.suspend();
                root.close();
            }
        }
        MIconButton {
            icon: "refresh"
            raised: true
            onClicked: root.requestPower("reboot")
        }
        MIconButton {
            icon: "power_settings_new"
            raised: true
            activeColor: Theme.urgent
            onClicked: root.requestPower("poweroff")
        }
    }

    // ── Body: controls column + accent / background rail ─────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.gapL

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: Theme.gapL

            VolumeRow {
                key: "out"
                icon: Audio.volumeIcon(Audio.volume, Audio.muted)
                muted: Audio.muted
                value: Audio.volume
                onToggleMute: Audio.toggleMute()
                onMoved: v => Audio.setVolume(v)
            }
            DevicePicker {
                key: "out"
                current: Audio.sink
                devices: Audio.outputs
                onPicked: node => Audio.setDefaultOutput(node)
            }
            VolumeRow {
                key: "in"
                icon: Audio.micMuted ? "mic_off" : "mic"
                muted: Audio.micMuted
                value: Audio.micVolume
                onToggleMute: Audio.toggleMicMute()
                onMoved: v => Audio.setMicVolume(v)
            }
            DevicePicker {
                key: "in"
                isOutput: false
                current: Audio.source
                devices: Audio.inputs
                onPicked: node => Audio.setDefaultInput(node)
            }

            Divider {}

            // Ethernet (status only).
            RowLayout {
                Layout.fillWidth: true
                visible: Network.ethDevice !== null
                spacing: Theme.gap
                MIcon {
                    text: "lan"
                    size: 20
                    color: Network.ethConnected ? Theme.primary : Theme.surfaceVariantText
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    MText { text: "Ethernet" }
                    MText { text: Network.ethConnected ? "Connected" : "Not connected"; muted: true; sizeDelta: -3 }
                    MText { visible: Network.ethConnected; text: "Local " + (Network.localIp || "…"); muted: true; sizeDelta: -3 }
                    MText { visible: Network.ethConnected; text: "External " + (Network.externalIp || "…"); muted: true; sizeDelta: -3 }
                }
                Rectangle {
                    implicitWidth: 8
                    implicitHeight: 8
                    radius: 4
                    color: Network.ethConnected ? Theme.good : Theme.surfaceVariantText
                }
            }
            Divider { visible: Network.ethDevice !== null }

            // Wi-Fi.
            ColumnLayout {
                Layout.fillWidth: true
                visible: Network.wifiDevice !== null
                spacing: Theme.gap

                TileHeader {
                    key: "wifi"
                    icon: Network.wifiEnabled ? "wifi" : "signal_wifi_off"
                    title: "Wi-Fi"
                    subtitle: Network.connectedSsid || (Network.wifiEnabled ? "Not connected" : "Off")
                    checked: Network.wifiEnabled
                    onToggled: Network.setWifiEnabled(!Network.wifiEnabled)
                    onSecondary: {
                        Network.openEditor();
                        root.close();
                    }
                }

                Repeater {
                    model: root.expanded === "wifi" ? root.wifiList : []
                    delegate: ColumnLayout {
                        id: net
                        required property var modelData
                        readonly property bool secured: modelData.security !== QsNet.WifiSecurityType.Open
                        readonly property bool entering: root.pskSsid === modelData.name
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        spacing: 2

                        function join() {
                            net.modelData.connectWithPsk(psk.text);
                            root.pskSsid = "";
                        }

                        Item {
                            Layout.fillWidth: true
                            implicitHeight: netLine.implicitHeight
                            RowLayout {
                                id: netLine
                                anchors.fill: parent
                                spacing: Theme.gap
                                MIcon {
                                    text: Network.signalIcon(net.modelData.signalStrength ?? 0)
                                    size: 16
                                    color: net.modelData.connected ? Theme.primary : Theme.surfaceVariantText
                                }
                                MText {
                                    text: net.modelData.name || "(hidden)"
                                    color: net.modelData.connected ? Theme.primary : Theme.surfaceText
                                    font.bold: net.modelData.connected
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                MIcon {
                                    visible: net.secured
                                    text: "lock"
                                    size: 13
                                    color: Theme.surfaceVariantText
                                }
                            }
                            // Connected → disconnect; known / open → connect;
                            // else toggle the passphrase row.
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    const n = net.modelData;
                                    if (n.connected)
                                        n.disconnect();
                                    else if (n.known || !net.secured)
                                        n.connect();
                                    else
                                        root.pskSsid = net.entering ? "" : n.name;
                                }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            visible: net.entering
                            spacing: Theme.gap
                            MTextField {
                                id: psk
                                Layout.fillWidth: true
                                icon: "password"
                                placeholder: "Passphrase"
                                password: true
                                consumeEscape: true // Escape cancels the passphrase, not the panel
                                // Restore what was typed if a rescan rebuilt the delegate.
                                Component.onCompleted: text = root.pskText
                                onTextChanged: root.pskText = text
                                onVisibleChanged: if (visible)
                                    Qt.callLater(() => psk.focusInput())
                                onAccepted: net.join()
                                onCanceled: root.pskSsid = ""
                            }
                            MIconButton {
                                icon: "close"
                                raised: true
                                onClicked: root.pskSsid = ""
                            }
                            MButton {
                                label: "Join"
                                filled: true
                                onClicked: net.join()
                            }
                        }
                    }
                }
            }
            Divider { visible: Network.wifiDevice !== null }

            // Bluetooth.
            ColumnLayout {
                Layout.fillWidth: true
                visible: Bluetooth.available
                spacing: Theme.gap

                TileHeader {
                    key: "bt"
                    icon: Bluetooth.connected.length > 0 ? "bluetooth_connected" : "bluetooth"
                    title: "Bluetooth"
                    subtitle: Bluetooth.summary
                    checked: Bluetooth.enabled
                    onToggled: Bluetooth.setEnabled(!Bluetooth.enabled)
                    onSecondary: {
                        Bluetooth.openManager();
                        root.close();
                    }
                }

                Repeater {
                    model: root.expanded === "bt" ? Bluetooth.devices : []
                    delegate: Item {
                        id: dev
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        implicitHeight: devLine.implicitHeight
                        RowLayout {
                            id: devLine
                            anchors.fill: parent
                            spacing: Theme.gap
                            MIcon {
                                text: dev.modelData.connected ? "bluetooth_connected" : "bluetooth"
                                size: 16
                                color: dev.modelData.connected ? Theme.primary : Theme.surfaceVariantText
                            }
                            MText {
                                text: dev.modelData.name || dev.modelData.address
                                color: dev.modelData.connected ? Theme.primary : Theme.surfaceText
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            MText {
                                visible: dev.modelData.pairing || (dev.modelData.connected && dev.modelData.batteryAvailable)
                                text: dev.modelData.pairing ? "pairing…" : dev.modelData.batteryAvailable ? Math.round(dev.modelData.battery * 100) + "%" : ""
                                muted: true
                                sizeDelta: -2
                            }
                        }
                        // Connected → disconnect; paired → connect; else pair.
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Bluetooth.activate(dev.modelData)
                        }
                    }
                }
            }
            Divider { visible: Bluetooth.available }

            // Do Not Disturb.
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.gap
                MIcon {
                    text: Notifications.dnd ? "do_not_disturb_on" : "do_not_disturb_off"
                    size: 20
                    color: Notifications.dnd ? Theme.primary : Theme.surfaceVariantText
                }
                MText { text: "Do Not Disturb"; Layout.fillWidth: true }
                MToggle {
                    checked: Notifications.dnd
                    onToggled: Notifications.dnd = !Notifications.dnd
                }
            }
        }

        // Accent swatches, then background presets (both persisted in Settings).
        ColumnLayout {
            Layout.alignment: Qt.AlignTop
            spacing: Theme.gap

            Repeater {
                model: Theme.accentOrder
                delegate: Rectangle {
                    required property string modelData
                    readonly property bool sel: Settings.accent === modelData
                    implicitWidth: 26
                    implicitHeight: 26
                    radius: width / 2
                    color: Theme.accents[modelData] ?? Theme.primary
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
                        color: Theme.contrastText(parent.color)
                    }
                    MouseArea {
                        id: swatchMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Settings.accent = parent.modelData
                    }
                }
            }
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 20
                implicitHeight: 1
                color: Theme.outline
                opacity: 0.5
            }
            Repeater {
                model: Theme.backgroundOrder
                delegate: Rectangle {
                    required property string modelData
                    readonly property bool sel: Settings.background === modelData
                    implicitWidth: 26
                    implicitHeight: 26
                    radius: Theme.radiusS
                    // `?? Theme.bg`: the palette loads async — for a moment the order list
                    // can name a preset the colour table doesn't have yet.
                    readonly property var preset: Theme.backgrounds[modelData] ?? Theme.bg
                    color: preset.surface
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
                        color: parent.preset.highest
                    }
                    MouseArea {
                        id: bgMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Settings.background = parent.modelData
                    }
                }
            }
        }
    }
}
