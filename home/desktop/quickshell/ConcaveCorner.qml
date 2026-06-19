// A concave (inverse-rounded) corner used where a dropdown meets the bar: a
// bar-coloured square with a quarter-circle scooped out of its outer-bottom,
// leaving a fillet that curves the panel's top edge out into the bar. Place one
// at each top corner of the panel (left/right mirror).
import QtQuick

Canvas {
    id: corner
    property color fillColor: Theme.bar
    property real radiusPx: Theme.radius
    property bool leftSide: true // left shoulder vs right shoulder

    width: radiusPx
    height: radiusPx

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        ctx.fillStyle = fillColor;
        ctx.fillRect(0, 0, radiusPx, radiusPx);
        // Carve the outer-bottom quarter circle.
        ctx.globalCompositeOperation = "destination-out";
        ctx.beginPath();
        ctx.arc(leftSide ? 0 : radiusPx, radiusPx, radiusPx, 0, 2 * Math.PI);
        ctx.fill();
    }

    onFillColorChanged: requestPaint()
    onRadiusPxChanged: requestPaint()
}
