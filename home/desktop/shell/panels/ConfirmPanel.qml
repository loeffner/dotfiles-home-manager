// Reboot / power-off confirmation ("confirm"), opened from the control panel —
// the island morphs from the controls into this card. Enter confirms, Escape
// (via the island) or Cancel dismisses.
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components
import qs.island
import qs.services

IslandPanel {
    id: root
    panelId: "confirm"
    panelWidth: 260

    // Snapshot of the action, taken on open: confirming clears Session.pending
    // before the card has folded away, which would flip the label mid-close.
    property string action: ""
    readonly property bool reboot: action === "reboot"

    onOpened: {
        action = Session.pending;
        Qt.callLater(() => keys.forceActiveFocus());
    }
    onClosed: Session.cancel()

    Item {
        id: keys
        Layout.fillWidth: true
        implicitHeight: 0
        Keys.onReturnPressed: {
            Session.confirm();
            root.close();
        }
        Keys.onEnterPressed: {
            Session.confirm();
            root.close();
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.gap
        MIcon {
            text: root.reboot ? "restart_alt" : "power_settings_new"
            size: 22
            color: Theme.urgent
        }
        MText {
            text: root.reboot ? "Reboot now?" : "Power off now?"
            sizeDelta: 1
            font.bold: true
            Layout.fillWidth: true
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.gap
        MButton {
            Layout.fillWidth: true
            label: "Cancel"
            onClicked: root.close()
        }
        MButton {
            Layout.fillWidth: true
            filled: true
            label: root.reboot ? "Reboot" : "Power off"
            onClicked: {
                Session.confirm();
                root.close();
            }
        }
    }
    MText {
        Layout.fillWidth: true
        text: "Enter to confirm · Esc to cancel"
        muted: true
        sizeDelta: -3
        horizontalAlignment: Text.AlignHCenter
    }
}
