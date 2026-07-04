// MToggle — a Material-3 switch. Emits toggled(); the caller flips `checked`.
import QtQuick

Item {
    id: root
    property bool checked: false
    signal toggled

    implicitWidth: 44
    implicitHeight: 26

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.primary : Theme.surfaceContainerHighest
        border.width: root.checked ? 0 : 2
        border.color: Theme.outline
        Behavior on color { ColorAnimation { duration: 150 } }

        Rectangle {
            id: knob
            width: root.checked ? 18 : 14
            height: width
            radius: height / 2
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? parent.width - width - 4 : 5
            color: root.checked ? Theme.primaryText : Theme.outline
            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 150 } }
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
