// ListRow — the hoverable/selectable row used by every list in the popouts.
// Encodes the hover rule once: the resting colour is the OPAQUE surface the row
// sits on (`restColor`, default the popout background), never "transparent" —
// Qt interpolates toward transparent as rgba(0,0,0,0), which flashes black when
// leaving hover. Hover is tracked with a HoverHandler so it stays lit over child
// controls. Emits clicked() for presses on the row background.
import QtQuick
import qs.config

Rectangle {
    id: root
    property bool selected: false
    property color restColor: Theme.popout
    property color hoverColor: Theme.surfaceContainer
    property color selectedColor: Theme.surfaceContainerHigh
    readonly property bool hovered: hover.hovered
    signal clicked

    radius: Theme.radiusS
    color: selected ? selectedColor : hovered ? hoverColor : restColor
    Behavior on color { ColorAnimation { duration: 110 } }

    HoverHandler { id: hover }
    MouseArea {
        anchors.fill: parent
        z: -1
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
