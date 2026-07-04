// CircleGauge — a circular progress ring (value 0..1) with centered big/small
// text and a caption below. Canvas-drawn (no QtQuick.Shapes dependency).
import QtQuick

Item {
    id: root
    property real value: 0
    property real value2: -1 // optional inner ring (e.g. temperature); <0 = none
    property string big: ""
    property string small: ""
    property string caption: ""
    property color arcColor: Theme.primary
    property color arcColor2: Theme.warn
    property real ringWidth: 6
    property real diameter: 84

    implicitWidth: diameter
    implicitHeight: diameter + (caption !== "" ? 18 : 0)

    Canvas {
        id: canvas
        width: root.diameter
        height: root.diameter
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top

        property real v: Math.max(0, Math.min(1, root.value))
        property real v2: Math.max(0, Math.min(1, root.value2))
        Behavior on v { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        Behavior on v2 { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        onVChanged: requestPaint()
        onV2Changed: requestPaint()
        Connections {
            target: root
            function onArcColorChanged() { canvas.requestPaint(); }
            function onArcColor2Changed() { canvas.requestPaint(); }
        }

        onPaint: {
            // DankMaterialShell's technique: a wide translucent copy of the value
            // arc behind the solid one makes a soft glow; the track is a faint
            // tint of the accent (not grey).
            const ctx = getContext("2d");
            ctx.reset();
            ctx.lineCap = "round";
            const cx = width / 2, cy = height / 2;
            const start = -Math.PI / 2;
            const thickness = Math.max(4, Math.min(width, height) / 15);
            const glowExtra = thickness * 1.4;
            const arcPadding = (thickness + glowExtra) / 2;

            function drawRing(radius, frac, col, glow) {
                if (frac > 0 && glow > 0) {
                    ctx.beginPath();
                    ctx.strokeStyle = Qt.rgba(col.r, col.g, col.b, 0.2 * glow);
                    ctx.lineWidth = thickness + glowExtra * glow;
                    ctx.arc(cx, cy, radius, start, start + 2 * Math.PI * frac);
                    ctx.stroke();
                }
                ctx.beginPath();
                ctx.strokeStyle = Qt.rgba(col.r, col.g, col.b, 0.1);
                ctx.lineWidth = thickness;
                ctx.arc(cx, cy, radius, 0, 2 * Math.PI);
                ctx.stroke();
                if (frac > 0) {
                    ctx.beginPath();
                    ctx.strokeStyle = Qt.rgba(col.r, col.g, col.b, 1);
                    ctx.lineWidth = thickness;
                    ctx.arc(cx, cy, radius, start, start + 2 * Math.PI * frac);
                    ctx.stroke();
                }
            }

            const rOuter = Math.min(width, height) / 2 - arcPadding;
            drawRing(rOuter, v, root.arcColor, 1.0);
            // Inner ring (temperature) sits close to the outer one, with a much
            // subtler glow so it doesn't bloom into the center text.
            if (root.value2 >= 0)
                drawRing(rOuter - thickness * 1.5, v2, root.arcColor2, 0.35);
        }

        Column {
            anchors.centerIn: parent
            spacing: 0
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.big
                color: Theme.surfaceText
                font.family: Theme.font
                font.pixelSize: Theme.fontSize + 2
                font.bold: true
            }
            Text {
                visible: root.small !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.small
                color: Theme.surfaceVariantText
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 3
            }
        }
    }

    Text {
        visible: root.caption !== ""
        anchors { top: canvas.bottom; topMargin: 2; horizontalCenter: parent.horizontalCenter }
        text: root.caption
        color: Theme.surfaceVariantText
        font.family: Theme.font
        font.pixelSize: Theme.fontSize - 2
    }
}
