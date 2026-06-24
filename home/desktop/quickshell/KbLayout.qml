// Keyboard-layout indicator. Hidden while the default layout (index 0, us) is
// active; shows a short code (e.g. "DE") in the accent colour whenever a
// non-default layout is in use, so it only draws attention when it matters.
// Click to cycle layouts (same as Mod+Alt+Space). State comes from the Niri
// singleton's event-stream tracking.
import QtQuick
import Quickshell

Item {
    id: root

    readonly property bool active: Niri.layoutIdx !== 0
    visible: active
    implicitWidth: active ? row.implicitWidth : 0
    implicitHeight: Theme.barHeight

    // Map niri's descriptive xkb name ("German", "English (US)", …) to a short
    // two-letter badge; fall back to the first letters of the name.
    function shortCode(name) {
        if (!name)
            return "??";
        const n = name.toLowerCase();
        if (n.indexOf("german") !== -1)
            return "DE";
        if (n.indexOf("english") !== -1)
            return "EN";
        if (n.indexOf("french") !== -1)
            return "FR";
        if (n.indexOf("spanish") !== -1)
            return "ES";
        return name.replace(/[^A-Za-z]/g, "").slice(0, 2).toUpperCase() || "??";
    }

    opacity: ma.containsMouse ? 1.0 : 0.88
    Behavior on opacity { NumberAnimation { duration: 70 } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.gap / 2

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰌌"
            color: Theme.accent
            font.family: Theme.font
            font.pixelSize: Theme.iconSize
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.shortCode(Niri.layoutNames[Niri.layoutIdx])
            color: Theme.accent
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            font.bold: true
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Niri.switchLayout()
    }
}
