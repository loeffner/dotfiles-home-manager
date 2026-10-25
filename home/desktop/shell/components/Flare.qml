// Flare — the concave "shoulder" where a popout meets the bar, so the popout reads
// as the bar itself flowing down (dynamic-island style). A size×size square filled
// with `color` minus a quarter circle: the left flare curves down into a popout on
// its right, `mirrored` flips it for the popout's right side.
import QtQuick
import qs.config

Canvas {
    id: flare
    property color color: Theme.bar
    property bool mirrored: false

    onColorChanged: requestPaint()
    onMirroredChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        const r = width;
        ctx.reset();
        ctx.fillStyle = flare.color;
        ctx.beginPath();
        if (!mirrored) {
            // Fill between the top edge, the right edge and an arc centred bottom-left.
            ctx.moveTo(0, 0);
            ctx.lineTo(r, 0);
            ctx.lineTo(r, r);
            ctx.arc(0, r, r, 0, -Math.PI / 2, true);
        } else {
            ctx.moveTo(r, 0);
            ctx.lineTo(0, 0);
            ctx.lineTo(0, r);
            ctx.arc(r, r, r, Math.PI, 3 * Math.PI / 2, false);
        }
        ctx.closePath();
        ctx.fill();
    }
}
