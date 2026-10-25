// MSlider — a Material-3 horizontal slider (rounded track + accent fill + thumb)
// with an optional leading icon. Controlled: `value` (0..1) stays bound to the
// source; dragging shows a live local position and emits moved(v) without
// overwriting `value`, so external changes (media keys) keep moving the thumb.
// Right-click sets 50%, the wheel steps 5%.
import QtQuick
import qs.config

Item {
    id: root
    property real value: 0.5
    property string icon: ""
    signal moved(real v)

    property bool _dragging: false
    property real _dragValue: 0
    readonly property real _shown: _dragging ? _dragValue : Math.max(0, Math.min(1, value))
    readonly property real _trackH: 12

    implicitHeight: 36
    implicitWidth: 200

    Row {
        anchors.fill: parent
        spacing: 10

        MIcon {
            visible: root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            size: 20
            color: Theme.surfaceVariantText
        }

        Item {
            width: parent.width - (root.icon !== "" ? 30 : 0)
            height: parent.height
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: root._trackH
                radius: root._trackH / 2
                color: Theme.surfaceContainerHighest
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(root._trackH, parent.width * root._shown)
                height: root._trackH
                radius: root._trackH / 2
                color: Theme.primary
            }
            Rectangle {
                width: 4
                height: parent.height - 6
                y: 3
                radius: 2
                color: Theme.surfaceText
                x: Math.max(0, Math.min(parent.width - width, parent.width * root._shown - width / 2))
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                function setFromX(px) {
                    const v = Math.max(0, Math.min(1, px / width));
                    root._dragValue = v;
                    root._dragging = true;
                    root.moved(v);
                }
                onPressed: e => {
                    if (e.button === Qt.RightButton) {
                        root._dragging = false;
                        root.moved(0.5);
                    } else {
                        setFromX(e.x);
                    }
                }
                onPositionChanged: e => {
                    if (pressed && (e.buttons & Qt.LeftButton))
                        setFromX(e.x);
                }
                onReleased: root._dragging = false
                onCanceled: root._dragging = false
                onWheel: w => root.moved(Math.max(0, Math.min(1, root.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
            }
        }
    }
}
