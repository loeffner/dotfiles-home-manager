// MButton — a Material-3 button (icon and/or label) with hover/press surface
// stepping. `filled` uses the primary accent; otherwise it's a subtle tile.
import QtQuick

Rectangle {
    id: root
    property string icon: ""
    property string label: ""
    property bool filled: false
    signal clicked
    signal rightClicked

    implicitHeight: 34
    implicitWidth: content.implicitWidth + 24
    radius: Theme.radiusM
    color: filled ? Theme.primary : ma.pressed ? Theme.surfaceContainerHighest : ma.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer
    Behavior on color { ColorAnimation { duration: 120 } }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 6

        MIcon {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            size: 18
            color: root.filled ? Theme.primaryText : Theme.surfaceText
        }
        Text {
            visible: root.label !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: root.filled ? Theme.primaryText : Theme.surfaceText
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => e.button === Qt.RightButton ? root.rightClicked() : root.clicked()
    }
}
