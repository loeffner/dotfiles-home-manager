// Miniature of the focused workspace's niri layout. Each column's bar-pixel
// width is proportional to its real pixel width: a full-screen column maps to
// fullScreenPx (40px). The total minimap width grows with open windows, and
// can use all bar space up to the clock.
import QtQuick

Row {
    id: root
    spacing: 2

    // A column that fills the whole monitor gets this many bar pixels.
    readonly property int fullScreenPx: 40
    readonly property int mapHeight: 16
    readonly property int minColPx: 5

    readonly property var cols: {
        const all = Niri.windows || [];
        if (all.length === 0)
            return [];
        const fw = all.find(w => w.focused);
        const wsId = fw ? fw.workspaceId : null;
        const ws = all.filter(w => !w.floating && (wsId === null || w.workspaceId === wsId));
        const map = {};
        let fallback = 1;
        for (const w of ws) {
            const c = (w.col === null || w.col === undefined) ? fallback++ : w.col;
            (map[c] = map[c] || []).push(w);
        }
        return Object.keys(map).sort((a, b) => a - b).map(k =>
            map[k].slice().sort((a, b) => (a.row || 0) - (b.row || 0))
        );
    }

    visible: cols.length > 0

    Repeater {
        model: root.cols

        delegate: Column {
            id: col
            required property var modelData
            spacing: 2

            readonly property real colScreenWidth: modelData[0].tileWidth || 1
            // Scale: fullScreenPx at monitor width, minimum minColPx.
            readonly property int colPx: Math.max(root.minColPx,
                Math.round(colScreenWidth / Niri.outputWidth * root.fullScreenPx)
            )

            Repeater {
                model: col.modelData

                delegate: Rectangle {
                    required property var modelData
                    width: col.colPx
                    height: Math.max(4,
                        (root.mapHeight - (col.modelData.length - 1) * 2) / col.modelData.length
                    )
                    radius: 2
                    color: modelData.focused ? Theme.accent : Theme.bg2

                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                }
            }
        }
    }
}
