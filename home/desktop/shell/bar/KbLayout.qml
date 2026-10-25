// Keyboard-layout badge, shown only while a non-default layout is active (e.g.
// "DE"). Click cycles layouts (same as Mod+Alt+Space).
import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root
    readonly property bool active: Niri.layoutIdx !== 0

    visible: active
    implicitWidth: active ? row.implicitWidth : 0
    implicitHeight: Theme.barHeight
    opacity: ma.containsMouse ? 1.0 : 0.88
    Behavior on opacity { NumberAnimation { duration: 70 } }

    // niri's descriptive xkb name ("German", "English (US)") → a short badge.
    function shortCode(name) {
        if (!name)
            return "??";
        const n = name.toLowerCase();
        for (const [k, code] of [["german", "DE"], ["english", "EN"], ["french", "FR"], ["spanish", "ES"]])
            if (n.indexOf(k) !== -1)
                return code;
        return name.replace(/[^A-Za-z]/g, "").slice(0, 2).toUpperCase() || "??";
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.gap / 2
        MIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: "keyboard"
            color: Theme.primary
            size: Theme.iconSize + 2
        }
        MText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.shortCode(Niri.layoutNames[Niri.layoutIdx])
            color: Theme.primary
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
