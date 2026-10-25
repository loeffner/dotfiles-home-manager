// StarField — a seeded, stable scatter of faint stars (LCG pseudo-random, so
// repaints don't move them). Embedders re-scatter by changing `seed`. Optional
// slow-breathing opacity pulse.
import QtQuick
import qs.config

Canvas {
    id: sf
    property int starCount: 60
    property int seed: 7
    property real maxOpacity: 0.28
    property real maxRadius: 1.5
    property bool twinkle: false
    property color color: Theme.starTint

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onSeedChanged: requestPaint()
    onColorChanged: requestPaint()
    onStarCountChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        ctx.fillStyle = sf.color;
        let s = seed >>> 0;
        const next = () => {
            s = ((s * 1664525) + 1013904223) >>> 0;
            return s / 0xFFFFFFFF;
        };
        for (let i = 0; i < starCount; i++) {
            const x = next() * width;
            const y = next() * height;
            const r = next() * maxRadius + 0.3;
            ctx.globalAlpha = next() * maxOpacity + 0.05;
            ctx.beginPath();
            ctx.arc(x, y, r, 0, 2 * Math.PI);
            ctx.fill();
        }
        ctx.globalAlpha = 1;
    }

    SequentialAnimation on opacity {
        loops: Animation.Infinite
        running: sf.twinkle
        NumberAnimation { from: 0.70; to: 1.0; duration: 4000; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1.0; to: 0.70; duration: 4000; easing.type: Easing.InOutSine }
    }
}
