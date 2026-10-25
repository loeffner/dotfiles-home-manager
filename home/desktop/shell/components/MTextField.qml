// MTextField — a Material-3 single-line text field with an optional leading icon
// and a reveal toggle for passwords. Popouts hold keyboard focus while open, so
// pressing the field (or focusInput()) just gives the input active focus.
// Escape emits canceled(); unless `consumeEscape` is set it then propagates up
// to the popout, which closes.
import QtQuick
import qs.config

Rectangle {
    id: root
    property alias text: input.text
    property string placeholder: ""
    property string icon: ""
    property bool password: false
    property bool consumeEscape: false
    property bool _reveal: false
    signal accepted
    signal canceled

    function clear() {
        input.text = "";
    }
    function focusInput() {
        input.forceActiveFocus();
    }

    implicitHeight: 32
    radius: Theme.radiusM
    color: Theme.surfaceContainerHigh
    border.width: 1
    border.color: input.activeFocus ? Theme.primary : Theme.outline
    Behavior on border.color { ColorAnimation { duration: 120 } }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: root.password ? 34 : 10 // room for the eye
        spacing: 6

        MIcon {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            size: 16
            color: Theme.surfaceVariantText
        }
        TextInput {
            id: input
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - (root.icon !== "" ? 22 : 0)
            color: Theme.surfaceText
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            clip: true
            echoMode: (root.password && !root._reveal) ? TextInput.Password : TextInput.Normal
            onAccepted: root.accepted()
            Keys.onEscapePressed: e => {
                root.canceled();
                e.accepted = root.consumeEscape;
            }

            MText {
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text === ""
                text: root.placeholder
                muted: true
            }
        }
    }

    // Overlay press → focus (click-to-position is sacrificed; fine for short fields).
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onPressed: root.focusInput()
    }

    MIcon {
        visible: root.password
        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
        text: root._reveal ? "visibility_off" : "visibility"
        size: 16
        color: eyeMa.containsMouse ? Theme.surfaceText : Theme.surfaceVariantText
        MouseArea {
            id: eyeMa
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root._reveal = !root._reveal
        }
    }
}
