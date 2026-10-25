// MIcon — a Material Symbols Rounded glyph, named by ligature (text: "settings"
// renders the gear). The variable font's FILL/wght/GRAD/opsz axes give the
// filled/outlined look.
import QtQuick
import qs.config

Text {
    property bool fill: false
    property int weight: 400
    property int grade: 0
    property real size: Theme.iconSize

    font.family: Theme.symbols
    font.pixelSize: size
    font.variableAxes: ({
            "FILL": fill ? 1 : 0,
            "wght": weight,
            "GRAD": grade,
            "opsz": size
        })
    color: Theme.surfaceText
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
}
