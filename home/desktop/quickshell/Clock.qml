// Bar clock. Click to open/close the dashboard (which includes the calendar).
import QtQuick
import Quickshell

Item {
    id: root
    implicitWidth: label.implicitWidth
    implicitHeight: Theme.barHeight

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Text {
        id: label
        anchors.centerIn: parent
        color: Theme.fg
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        text: Qt.formatDateTime(clock.date, "ddd dd MMM   HH:mm")
    }

    opacity: ma.containsMouse ? 1.0 : 0.88
    Behavior on opacity { NumberAnimation { duration: 70 } }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: ShellState.dashboardOpen = !ShellState.dashboardOpen
    }
}
