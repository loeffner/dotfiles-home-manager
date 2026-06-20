// Full-screen power modal. The dark overlay IS the backdrop — clicking anywhere
// outside the card closes it. Four actions: Suspend / Reboot / Power off / Log out.
import QtQuick
import QtQuick.Layouts
import Quickshell

PanelWindow {
    id: win
    required property var modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    visible: false

    // Deep space void — Gruvbox bg0_h (#1d2021) at high opacity rather than
    // plain black, so the overlay matches the bar and feels like space itself.
    color: Qt.rgba(0, 0, 0, 0)
    NumberAnimation on color {
        id: fadeIn; to: Qt.rgba(0.114, 0.125, 0.129, 0.92)
        duration: 130; easing.type: Easing.OutQuart
        running: false
    }
    NumberAnimation on color {
        id: fadeOut; to: Qt.rgba(0, 0, 0, 0)
        duration: 80; easing.type: Easing.InQuart
        running: false
        onFinished: win.visible = false
    }

    Connections {
        target: ShellState
        function onPowerOpenChanged() {
            if (ShellState.powerOpen) {
                win.visible = true;
                fadeOut.stop();
                fadeIn.start();
            } else {
                fadeIn.stop();
                fadeOut.start();
            }
        }
    }

    // Deep-space starfield — large, dramatic, slow-breathing.
    StarField {
        anchors.fill: parent
        starCount: 160
        seed: 42
        maxOpacity: 0.55
        maxRadius: 2.4
        twinkle: true
    }

    // Click outside the card to dismiss.
    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.powerOpen = false
    }

    // Centred card.
    Rectangle {
        anchors.centerIn: parent
        color: Theme.bgPopup
        radius: Theme.radius + 4
        border.width: 1
        border.color: Theme.border
        implicitWidth: row.implicitWidth + Theme.pad * 4
        implicitHeight: row.implicitHeight + Theme.pad * 4

        // Stop backdrop clicks reaching the outer MouseArea.
        MouseArea { anchors.fill: parent }

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: Theme.pad * 2

            Repeater {
                model: [
                    { glyph: "󰒲", label: "Suspend",   cmd: ["systemctl", "suspend"],    color: "" },
                    { glyph: "󰑓", label: "Reboot",    cmd: ["systemctl", "reboot"],     color: "" },
                    { glyph: "󰐦", label: "Power off", cmd: ["systemctl", "poweroff"],   color: "urgent" },
                    { glyph: "󰍃", label: "Log out",   cmd: ["niri", "msg", "action", "quit"], color: "" }
                ]

                delegate: ColumnLayout {
                    required property var modelData
                    spacing: Theme.gap

                    Rectangle {
                        id: btn
                        Layout.alignment: Qt.AlignHCenter
                        width: 72; height: 72
                        radius: Theme.radius
                        color: ma.containsMouse ? Theme.bg1 : Theme.bg2

                        Behavior on color { ColorAnimation { duration: 120 } }
                        Behavior on radius {
                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: btn.parent.modelData.glyph
                            font.family: Theme.font
                            font.pixelSize: 30
                            color: btn.parent.modelData.color === "urgent" ? Theme.urgent : Theme.fg
                        }

                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: parent.radius = Theme.radius * 2
                            onExited: parent.radius = Theme.radius
                            onClicked: {
                                ShellState.powerOpen = false;
                                Quickshell.execDetached(btn.parent.modelData.cmd);
                            }
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: parent.modelData.label
                        color: Theme.dim
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 1
                    }
                }
            }
        }
    }
}
