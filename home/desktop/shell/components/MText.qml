// MText — shell text with the font baked in. `muted` switches to the secondary
// colour, `sizeDelta` offsets from the base size (e.g. -2 for captions, +1 for
// panel titles).
import QtQuick
import qs.config

Text {
    property bool muted: false
    property int sizeDelta: 0

    color: muted ? Theme.surfaceVariantText : Theme.surfaceText
    font.family: Theme.font
    font.pixelSize: Theme.fontSize + sizeDelta
}
