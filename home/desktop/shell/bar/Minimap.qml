// Minimap of this output's active workspace: one bar per tiled column, its width
// proportional to the column's real width, stacked tiles split the height. Click
// a tile to focus that window.
import QtQuick
import qs.config
import qs.services

Row {
    id: root
    required property var screen
    spacing: 2

    // A column as wide as the monitor gets this many bar pixels.
    readonly property int fullScreenPx: 72
    readonly property int mapHeight: 16
    readonly property int minColPx: 5

    readonly property int workspaceId: Niri.workspacesOn(screen?.name ?? "").find(w => w.active)?.id ?? Niri.focusedWorkspaceId
    readonly property var cols: {
        const wins = Niri.windows.filter(w => !w.floating && w.workspaceId === workspaceId);
        const map = {};
        let fallback = 1;
        for (const w of wins) {
            const c = (w.col === null || w.col === undefined) ? fallback++ : w.col;
            (map[c] = map[c] || []).push(w);
        }
        return Object.keys(map).sort((a, b) => a - b).map(k => map[k].slice().sort((a, b) => (a.row || 0) - (b.row || 0)));
    }

    visible: cols.length > 0

    Repeater {
        model: root.cols

        delegate: Column {
            id: col
            required property var modelData
            readonly property int colPx: Math.max(root.minColPx, Math.round((modelData[0].tileWidth || 1) / Niri.outputWidth * root.fullScreenPx))
            spacing: 2

            Repeater {
                model: col.modelData
                delegate: Rectangle {
                    id: tile
                    required property var modelData
                    width: col.colPx
                    height: Math.max(4, (root.mapHeight - (col.modelData.length - 1) * 2) / col.modelData.length)
                    radius: 2
                    color: modelData.focused ? Theme.primary : Theme.surfaceContainerHighest
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Niri.focusWindow(tile.modelData.id)
                    }
                }
            }
        }
    }
}
