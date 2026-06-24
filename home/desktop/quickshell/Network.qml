// Network widget backed by Quickshell.Networking (NetworkManager over DBus).
//
// Bar icon reflects connection state. Clicking opens a panel that lists Wi-Fi
// networks (auto-scans while open; click to connect, with an inline passphrase
// field for secured/unknown ones) and always offers an nm-connection-editor
// escape hatch.
//
// Property names verified against quickshell-0.3.0's qmltypes: a Network's SSID
// is `name`; WifiNetwork adds `signalStrength` (0–1), `security`
// (WifiSecurityType) and `connectWithPsk()`; saved networks report `known`.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking

Item {
    id: root
    required property var bar

    implicitWidth: icon.implicitWidth
    implicitHeight: Theme.barHeight

    // Inline-passphrase state lives here, not in the Repeater delegate: a Wi-Fi
    // rescan swaps out `wifiDev.networks`, which rebuilds every delegate and
    // would otherwise wipe the field. `pskSsid` is the network whose field is
    // open; `pskText` is what's been typed so far.
    property string pskSsid: ""
    property string pskText: ""

    // Scan only while the panel is open. (Don't pause scanning during passphrase
    // entry: disabling the scanner empties wifiDev.networks, which would destroy
    // the row you're typing into. The hoisted pskText below survives a rescan
    // rebuild instead.)
    function syncScanner() {
        if (root.wifiDev)
            root.wifiDev.scannerEnabled = popup.isOpen;
    }

    opacity: ma.containsMouse ? 1.0 : 0.82
    Behavior on opacity {
        NumberAnimation {
            duration: 70
        }
    }

    readonly property var devices: Networking.devices?.values ?? []
    readonly property var activeDev: devices.find(d => d.connected) ?? null
    readonly property bool online: activeDev !== null
    // Wi-Fi devices expose `scannerEnabled`; wired ones don't — a reliable
    // runtime discriminator without depending on enum values.
    readonly property var wifiDev: devices.find(d => d.scannerEnabled !== undefined) ?? null
    readonly property bool activeIsWifi: activeDev ? (activeDev.scannerEnabled !== undefined) : false

    function glyph() {
        if (!online)
            return "󰤭";               // disconnected
        return activeIsWifi ? "󰤨" : "󰈀"; // wifi / ethernet
    }

    Text {
        id: icon
        anchors.centerIn: parent
        text: root.glyph()
        font.family: Theme.font
        font.pixelSize: Theme.iconSize
        color: root.online ? Theme.fg : Theme.urgent
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: popup.toggle()
    }

    BarPopup {
        id: popup
        bar: root.bar
        anchorItem: root
        popWidth: 340

        // Scan for networks only while the panel is open; reset any in-progress
        // passphrase entry when it closes.
        Connections {
            target: popup
            function onVisibleChanged() {
                if (!popup.isOpen) {
                    root.pskSsid = "";
                    root.pskText = "";
                }
                root.syncScanner();
            }
        }

        // Status line.
        Text {
            Layout.fillWidth: true
            text: root.online ? ("Connected" + (root.activeDev.name ? " · " + root.activeDev.name : "")) : "Offline"
            color: root.online ? Theme.good : Theme.urgent
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }

        // Wi-Fi enable toggle — only when a Wi-Fi device is present.
        Item {
            Layout.fillWidth: true
            visible: root.wifiDev !== null
            implicitHeight: wifiRow.implicitHeight

            RowLayout {
                id: wifiRow
                anchors.fill: parent
                Text {
                    text: "Wi-Fi"
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    Layout.fillWidth: true
                }
                Text {
                    text: Networking.wifiEnabled ? "On" : "Off"
                    color: Networking.wifiEnabled ? Theme.good : Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
            }
        }

        // Available networks, connected first then by signal strength.
        Repeater {
            model: {
                if (!root.wifiDev)
                    return [];
                const nets = (root.wifiDev.networks?.values ?? []).slice();
                nets.sort((a, b) => (b.connected - a.connected) || ((b.signalStrength ?? 0) - (a.signalStrength ?? 0)));
                return nets;
            }

            delegate: ColumnLayout {
                id: netRow
                required property var modelData
                readonly property bool secured: modelData.security !== WifiSecurityType.Open
                readonly property bool expanded: root.pskSsid === modelData.name

                Layout.fillWidth: true
                spacing: 4

                Item {
                    Layout.fillWidth: true
                    implicitHeight: ssidRow.implicitHeight

                    RowLayout {
                        id: ssidRow
                        anchors.fill: parent
                        spacing: Theme.gap

                        Text {
                            text: {
                                const s = netRow.modelData.signalStrength ?? 0;
                                if (s > 0.75)
                                    return "󰤨";
                                if (s > 0.5)
                                    return "󰤥";
                                if (s > 0.25)
                                    return "󰤢";
                                return "󰤟";
                            }
                            color: netRow.modelData.connected ? Theme.good : Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.iconSize
                        }
                        Text {
                            text: netRow.modelData.name || "(hidden network)"
                            color: netRow.modelData.connected ? Theme.good : Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            font.bold: netRow.modelData.connected
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            visible: netRow.secured
                            text: "󰌾"
                            color: Theme.dim
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const n = netRow.modelData;
                            if (n.connected)
                                n.disconnect();
                            else if (n.known || !netRow.secured)
                                n.connect();          // saved or open network
                            else if (netRow.expanded)
                                root.pskSsid = "";    // collapse the field
                            else {
                                root.pskSsid = n.name; // ask for a passphrase
                                root.pskText = "";
                                psk.text = "";
                            }
                        }
                    }
                }

                // Inline passphrase entry for secured, unknown networks.
                RowLayout {
                    Layout.fillWidth: true
                    visible: netRow.expanded
                    spacing: Theme.gap

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 26
                        radius: 6
                        color: Theme.bg1

                        TextInput {
                            id: psk
                            anchors {
                                fill: parent
                                leftMargin: 8
                                rightMargin: 8
                            }
                            verticalAlignment: TextInput.AlignVCenter
                            echoMode: TextInput.Password
                            color: Theme.fg
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            clip: true
                            // Seed from the hoisted text so a rescan-driven
                            // rebuild restores what was typed; write edits back.
                            Component.onCompleted: text = root.pskText
                            onTextChanged: root.pskText = text
                            // Grab focus as soon as the row expands so typing
                            // lands here, not in the previously focused window.
                            onVisibleChanged: if (visible) forceActiveFocus()
                            onAccepted: {
                                netRow.modelData.connectWithPsk(text);
                                root.pskSsid = "";
                            }
                        }
                    }
                    Text {
                        text: "Connect"
                        color: Theme.accent
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                netRow.modelData.connectWithPsk(root.pskText);
                                root.pskSsid = "";
                            }
                        }
                    }
                }
            }
        }

        // Separator + escape hatch to the full editor (always available).
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.border
        }
        Text {
            text: "Advanced settings…"
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Quickshell.execDetached(["nm-connection-editor"]);
                    popup.hide();
                }
            }
        }
    }
}
