// Mail button: opens the mail panel. Accent + an unread-count badge while there
// is unread mail.
import QtQuick
import qs.config
import qs.components
import qs.services

BarIcon {
    id: root
    required property var screen
    readonly property int unread: Mail.unreadCount

    icon: unread > 0 ? "mark_email_unread" : "mail"
    active: Popouts.isOpen(screen, "mail")
    colorOverride: unread > 0 && !active ? Theme.primary : undefined
    onClicked: Popouts.toggle(screen, "mail", root)

    Rectangle {
        visible: root.unread > 0
        anchors { left: root.glyph.right; top: root.glyph.top; leftMargin: -8; topMargin: -3 }
        height: 15
        width: Math.max(15, count.implicitWidth + 8)
        radius: 7.5
        color: Theme.primary
        border.width: 2
        border.color: Theme.bar
        MText {
            id: count
            anchors.centerIn: parent
            text: root.unread > 99 ? "99+" : root.unread
            sizeDelta: -3
            font.bold: true
            color: Theme.primaryText
        }
    }
}
