// MIconButton — a round Material-3 icon button (header/toolbar actions). `active`
// shows a selected state in the accent colour.
import QtQuick

Rectangle {
    id: root
    property string icon: ""
    property real size: 20
    property bool active: false
    property bool raised: false // persistent subtle background (always visible)
    property color activeColor: Theme.primary
    signal clicked

    implicitWidth: 32
    implicitHeight: 32
    radius: width / 2
    color: active ? Theme.surfaceContainerHighest : ma.containsMouse ? (raised ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh) : (raised ? Theme.surfaceContainerHigh : "transparent")
    Behavior on color { ColorAnimation { duration: 120 } }

    MIcon {
        anchors.centerIn: parent
        text: root.icon
        size: root.size
        fill: root.active
        color: root.active ? root.activeColor : Theme.surfaceText
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
