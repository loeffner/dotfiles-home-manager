// MTextField — a Material-3 single-line text field with an optional leading icon.
// Popouts always hold keyboard focus while open, so pressing the field (or
// calling focusInput()) just gives the input active focus.
import QtQuick

Rectangle {
    id: root
    property alias text: input.text
    property string placeholder: ""
    property string icon: ""
    property bool password: false
    property bool _reveal: false // password shown (eye toggled)
    // Escape always emits canceled(); unless consumed it then propagates up to the
    // Popout, which closes. Set for fields whose cancel is a local action.
    property bool consumeEscape: false
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
        anchors.rightMargin: root.password ? 34 : 10 // reserve room for the eye
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

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text === ""
                text: root.placeholder
                color: Theme.surfaceVariantText
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
            }
        }
    }

    // Overlay press → request focus. (Click-to-position-cursor is sacrificed,
    // which is fine for a short field.)
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onPressed: root.focusInput()
    }

    // Reveal/hide toggle for password fields (on top of the focus overlay).
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
