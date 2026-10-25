// BarIcon — a clickable Material Symbol in the bar: accent + filled while its
// popout is `active`, accent tint and a slight grow on hover. `tint` sets the
// resting colour; `colorOverride` (when defined) wins over every state.
import QtQuick
import qs.config

Item {
    id: root
    property string icon: ""
    property bool active: false
    property real size: 20
    property color tint: Theme.surfaceText
    property var colorOverride: undefined
    readonly property alias glyph: glyph
    readonly property bool hovered: ma.containsMouse
    signal clicked
    signal rightClicked

    implicitWidth: glyph.implicitWidth
    implicitHeight: Theme.barHeight

    MIcon {
        id: glyph
        anchors.centerIn: parent
        text: root.icon
        size: root.size
        fill: root.active
        color: root.colorOverride !== undefined ? root.colorOverride : root.active ? Theme.primary : ma.containsMouse ? Theme.iconHover : root.tint
        scale: ma.containsMouse ? 1.15 : 1.0
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => e.button === Qt.RightButton ? root.rightClicked() : root.clicked()
    }
}
