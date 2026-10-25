// Notification bell: opens the notification center; right-click toggles Do Not
// Disturb. Accent + a dot while notifications are active; greyed out in DND.
import QtQuick
import qs.config
import qs.components
import qs.services

BarIcon {
    id: root
    required property var screen
    readonly property bool hasActive: Notifications.activeCount > 0

    icon: Notifications.dnd ? "notifications_off" : hasActive ? "notifications_active" : "notifications"
    active: Popouts.isOpen(screen, "notifications")
    colorOverride: Notifications.dnd ? Theme.surfaceVariantText : hasActive ? Theme.primary : undefined
    onClicked: Popouts.toggle(screen, "notifications", root)
    onRightClicked: Notifications.dnd = !Notifications.dnd

    Rectangle {
        visible: root.hasActive && !Notifications.dnd
        anchors { right: root.glyph.right; top: root.glyph.top; rightMargin: -2; topMargin: 1 }
        width: 8
        height: 8
        radius: 4
        color: Theme.primary
        border.width: 2
        border.color: Theme.bar
    }
}
