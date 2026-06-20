// Pictographic keybind cheatsheet — a light overlay meant to be shown while
// holding Super (wired via keyd → `qs ipc call cheatsheet open/close`). Like the
// OSD it floats over the desktop without a dim backdrop: two small panels (the
// function-row media cluster up top, HJKL navigation + a few important binds
// down low) fade in, and the rest of the screen stays visible and clickable.
//
// Pictogram + key only, no descriptive text. Glyphs are Nerd Font (MesloLGS NF)
// and easy to swap if one doesn't read well.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

PanelWindow {
    id: win
    required property var modelData
    screen: modelData

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: false

    // IPC: keyd calls `open` on Super-hold, `close` on release; `toggle` for a tap.
    // (Avoid naming a function `show` — it collides with the `qs ipc show` verb.)
    IpcHandler {
        target: "cheatsheet"
        function open(): string { ShellState.cheatOpen = true; return "ok"; }
        function close(): string { ShellState.cheatOpen = false; return "ok"; }
        function toggle(): string { ShellState.cheatOpen = !ShellState.cheatOpen; return "ok"; }
    }

    Connections {
        target: ShellState
        function onCheatOpenChanged() {
            if (ShellState.cheatOpen) {
                win.visible = true;
                fadeOut.stop();
                fadeIn.start();
            } else {
                fadeIn.stop();
                fadeOut.start();
            }
        }
    }

    // Both panels fade together.
    Item {
        id: content
        anchors.fill: parent
        opacity: 0

        NumberAnimation {
            id: fadeIn; target: content; property: "opacity"; to: 1
            duration: 110; easing.type: Easing.OutQuart
        }
        NumberAnimation {
            id: fadeOut; target: content; property: "opacity"; to: 0
            duration: 90; easing.type: Easing.InQuart
            onFinished: win.visible = false
        }

        // Light dim wash — the desktop stays visible through it. Clicking it (or
        // anywhere outside a tile) dismisses, matching the tap-toggle flow.
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0.114, 0.125, 0.129, 0.4)
        }
        MouseArea {
            anchors.fill: parent
            onClicked: ShellState.cheatOpen = false
        }

        // ── Reusable pictogram + keycap tile ────────────────────────────────
        component KeyTile: ColumnLayout {
            property string glyph: ""
            property string key: ""
            property color glyphColor: Theme.fg
            spacing: 5

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: glyph
                color: glyphColor
                font.family: Theme.font
                font.pixelSize: 26
            }
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: Math.max(30, cap.implicitWidth + 16)
                implicitHeight: 22
                radius: 6
                color: Theme.bg2
                border.width: 1
                border.color: Theme.border
                Text {
                    id: cap
                    anchors.centerIn: parent
                    text: key
                    color: Theme.accent
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 1
                    font.bold: true
                }
            }
        }

        // ── Top panel: function-row media cluster (volume | playback) ───────
        Rectangle {
            id: topPanel
            anchors { top: parent.top; topMargin: Theme.barHeight + 28; horizontalCenter: parent.horizontalCenter }
            implicitWidth: topRow.implicitWidth + Theme.pad * 3
            implicitHeight: topRow.implicitHeight + Theme.pad * 2
            radius: Theme.radius + 4
            color: Theme.bgPopup
            border.width: 1
            border.color: Theme.border

            RowLayout {
                id: topRow
                anchors.centerIn: parent
                spacing: Theme.pad * 2

                Repeater {
                    model: [
                        { key: "F1", glyph: "󰝟" },  // mute
                        { key: "F2", glyph: "󰕿" },  // volume down
                        { key: "F3", glyph: "󰕾" }   // volume up
                    ]
                    delegate: KeyTile { required property var modelData; key: modelData.key; glyph: modelData.glyph }
                }

                Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 40; color: Theme.border; opacity: 0.5 }

                Repeater {
                    model: [
                        { key: "F7", glyph: "󰒮" },  // previous
                        { key: "F8", glyph: "󰐎" },  // play / pause
                        { key: "F9", glyph: "󰒭" }   // next
                    ]
                    delegate: KeyTile { required property var modelData; key: modelData.key; glyph: modelData.glyph }
                }
            }
        }

        // ── Bottom panel: navigation (HJKL) + a few important binds ─────────
        Rectangle {
            id: bottomPanel
            anchors { bottom: parent.bottom; bottomMargin: 56; horizontalCenter: parent.horizontalCenter }
            implicitWidth: bottomCol.implicitWidth + Theme.pad * 3
            implicitHeight: bottomCol.implicitHeight + Theme.pad * 2
            radius: Theme.radius + 4
            color: Theme.bgPopup
            border.width: 1
            border.color: Theme.border

            ColumnLayout {
                id: bottomCol
                anchors.centerIn: parent
                spacing: Theme.pad * 1.5

                // HJKL focus cluster. Arrows are the pictogram, the letter is the key.
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Theme.pad * 2
                    Repeater {
                        model: [
                            { key: "H", glyph: "←" },
                            { key: "J", glyph: "↓" },
                            { key: "K", glyph: "↑" },
                            { key: "L", glyph: "→" }
                        ]
                        delegate: KeyTile { required property var modelData; key: modelData.key; glyph: modelData.glyph; glyphColor: Theme.accent }
                    }
                }

                Rectangle { Layout.alignment: Qt.AlignHCenter; Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.border; opacity: 0.5 }

                // App / window / workspace shortcuts.
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Theme.pad * 2
                    Repeater {
                        model: [
                            { key: "↵", glyph: "󰆍" },   // terminal
                            { key: "B", glyph: "󰈹" },   // firefox
                            { key: "E", glyph: "󰉋" },   // files (yazi)
                            { key: "R", glyph: "󰀻" },   // launcher
                            { key: "O", glyph: "󰕰" },   // overview
                            { key: "F", glyph: "󰊓" },   // maximize column
                            { key: "V", glyph: "󱂬" },   // float toggle
                            { key: "Q", glyph: "󰅖" },   // close window
                            { key: "1-5", glyph: "󰧨" }  // workspaces
                        ]
                        delegate: KeyTile {
                            required property var modelData
                            key: modelData.key
                            glyph: modelData.glyph
                        }
                    }
                }
            }
        }
    }
}
