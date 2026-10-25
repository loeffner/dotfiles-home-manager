// Bar clock, pinned to the bar's centre. Opens the clock panel (calendar +
// now-playing). Hover tints it and grows it slightly — a render transform, so
// the flanking bell / play button never shift.
import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

Item {
    id: root
    required property var screen
    readonly property bool open: Popouts.isOpen(screen, "clock")

    implicitWidth: label.implicitWidth
    implicitHeight: Theme.barHeight
    scale: (ma.containsMouse || open) ? 1.06 : 1.0
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
    MText {
        id: label
        anchors.centerIn: parent
        color: (ma.containsMouse || root.open) ? Theme.iconHover : Theme.surfaceText
        text: Qt.formatDateTime(clock.date, "ddd dd MMM   HH:mm")
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Popouts.toggle(root.screen, "clock", root)
    }
}
