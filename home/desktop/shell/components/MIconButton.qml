// MIconButton — a round Material-3 icon button. `active` shows a selected state
// in `activeColor`; `raised` keeps a subtle background at rest. The non-raised
// rest colour is the opaque surface it sits on (`restColor`), never
// "transparent" — animating to transparent flashes through black.
import QtQuick
import qs.config

Rectangle {
    id: root
    property string icon: ""
    property real size: 20
    property bool active: false
    property bool raised: false
    property color activeColor: Theme.primary
    property color restColor: Theme.popout
    signal clicked

    implicitWidth: 32
    implicitHeight: 32
    radius: width / 2
    color: active ? Theme.surfaceContainerHighest
         : ma.containsMouse ? (raised ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)
         : (raised ? Theme.surfaceContainerHigh : restColor)
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
