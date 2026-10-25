// Chevron — the expand/collapse caret: points down, rotates up when `expanded`.
// Click target extends a few pixels past the glyph.
import QtQuick
import qs.config

MIcon {
    id: root
    property bool expanded: false
    signal clicked

    text: "expand_more"
    size: 18
    rotation: expanded ? 180 : 0
    color: Theme.surfaceVariantText
    Behavior on rotation { NumberAnimation { duration: 150 } }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -6
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
