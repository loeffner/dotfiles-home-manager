// Seeded starfield — stable positions across repaints (LCG pseudo-random).
// Stars use the warm earth-ivory accent colour. Optional slow-breathing
// opacity pulse makes the field feel alive without distracting movement.
import QtQuick

Canvas {
    id: sf

    property int   starCount:   60
    property int   seed:        7
    property real  maxOpacity:  0.28
    property real  maxRadius:   1.5   // px — raise for larger, more dramatic stars
    property bool  twinkle:     false // gentle full-field opacity breath
    property color color:       "#bdae93" // star tint (warm ivory by default)

    onWidthChanged:  requestPaint()
    onHeightChanged: requestPaint()
    onSeedChanged:   requestPaint() // re-scatter when embedders randomize the seed
    onColorChanged:  requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        ctx.fillStyle = sf.color;
        let s = seed >>> 0;
        const next = () => { s = ((s * 1664525) + 1013904223) >>> 0; return s / 0xFFFFFFFF; };
        for (let i = 0; i < starCount; i++) {
            const x = next() * width;
            const y = next() * height;
            const r = next() * maxRadius + 0.3;
            const a = next() * maxOpacity + 0.05;
            ctx.globalAlpha = a;
            ctx.beginPath();
            ctx.arc(x, y, r, 0, 2 * Math.PI);
            ctx.fill();
        }
        ctx.globalAlpha = 1;
    }

    // Slow inhale / exhale — all stars pulse in unison, like deep space breathing.
    SequentialAnimation on opacity {
        loops: Animation.Infinite
        running: sf.twinkle
        NumberAnimation { from: 0.70; to: 1.0; duration: 4000; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1.0; to: 0.70; duration: 4000; easing.type: Easing.InOutSine }
    }
}
