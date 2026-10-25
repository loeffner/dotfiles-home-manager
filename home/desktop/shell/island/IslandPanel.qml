// IslandPanel — base for a popout panel hosted by the screen's Island. Declare
// content as children (laid out in a column with the popout padding/spacing).
// The Island sets `screen`; `isOpen` follows Popouts, and opened()/closed() fire
// on the transitions (e.g. to reset or focus things).
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

Item {
    id: root
    required property string panelId
    property int panelWidth: 360
    property var screen: null // set by the Island
    property bool shown: false // set by the Island: this panel's content is on screen
    readonly property bool isOpen: screen !== null && Popouts.isOpen(screen, panelId)
    readonly property real contentHeight: body.implicitHeight + Theme.padL * 2
    default property alias content: body.data
    signal opened
    signal closed

    function close() {
        if (isOpen)
            Popouts.close(screen);
    }

    onIsOpenChanged: isOpen ? opened() : closed()

    width: panelWidth
    height: contentHeight
    opacity: shown ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Theme.durShort; easing.type: Easing.OutCubic } }

    ColumnLayout {
        id: body
        anchors { fill: parent; margins: Theme.padL }
        spacing: Theme.gapL
    }
}
