// Quick-settings pill: live network / bluetooth / volume (+ a red mic-off while
// the mic is muted). Opens the control panel; hover tints the whole pill.
import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root
    required property var screen
    readonly property bool hot: Popouts.isOpen(screen, "control") || ma.containsMouse

    implicitWidth: pill.implicitWidth
    implicitHeight: Theme.barHeight

    Row {
        id: pill
        anchors.centerIn: parent
        spacing: 5
        scale: ma.containsMouse ? 1.12 : 1.0
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        MIcon {
            text: Network.icon
            size: 18
            color: root.hot ? Theme.iconHover : Network.online ? Theme.surfaceText : Theme.surfaceVariantText
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        MIcon {
            text: Bluetooth.icon
            size: 18
            color: root.hot ? Theme.iconHover : Bluetooth.connected.length > 0 ? Theme.primary : Bluetooth.enabled ? Theme.surfaceText : Theme.surfaceVariantText
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        MIcon {
            text: Audio.volumeIcon(Audio.volume, Audio.muted)
            size: 18
            color: root.hot ? Theme.iconHover : Audio.muted ? Theme.surfaceVariantText : Theme.surfaceText
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        MIcon {
            visible: Audio.micMuted
            text: "mic_off"
            size: 18
            color: Theme.urgent
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Popouts.toggle(root.screen, "control", root)
    }
}
