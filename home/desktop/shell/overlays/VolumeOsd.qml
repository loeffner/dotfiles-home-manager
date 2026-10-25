// Volume / mic OSD: shown on volume or mic-mute changes and hidden after 1.5 s.
// Drawn like the island — the bar's colour flowing down out of the control pill,
// joined to the bar by concave flares, bottom corners rounded, starfield
// backdrop. It morphs out of the pill (spring overshoot) and folds back into it,
// snapping flush to a screen edge it would land within a flare's width of. It
// stays away while a panel is open on its screen (the island owns the space
// under the bar then). Click-through.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

PanelWindow {
    id: osd
    required property var modelData
    required property Item anchorItem // the bar's control pill
    screen: modelData

    property string mode: "volume" // "volume" | "mic"
    property bool shown: false
    readonly property int cardWidth: 380
    readonly property real cardHeight: row.implicitHeight + Theme.padL * 2
    readonly property bool _panelOpen: Popouts.current(modelData) !== ""

    // ── Geometry ─────────────────────────────────────────────────────────────
    // Measured on every show: mapToItem() isn't reactive, so a binding would
    // freeze at the pill's pre-layout position (x = 0, the left edge).
    property real _anchorX: 0
    property real _anchorW: 0
    property real cardX: 0
    property bool _atLeft: false
    property bool _atRight: false

    function _measure() {
        _anchorX = anchorItem.mapToItem(null, 0, 0).x;
        _anchorW = anchorItem.width;
        // The screen width, not the window's (0 wide before the first map).
        const sw = modelData.width;
        const want = _anchorX + _anchorW / 2 - cardWidth / 2;
        _atLeft = want < Theme.flareRadius;
        _atRight = want > sw - cardWidth - Theme.flareRadius;
        cardX = _atRight ? sw - cardWidth : _atLeft ? 0 : want;
    }

    // ── Show / hide ──────────────────────────────────────────────────────────
    function show(m) {
        if (_panelOpen)
            return;
        mode = m;
        hideTimer.restart();
        if (shown)
            return;
        _measure();
        starfield.seed = Math.floor(Math.random() * 2147483647);
        shown = true;
        exitAnim.stop();
        enterAnim.restart();
    }
    function hide() {
        if (!shown)
            return;
        shown = false;
        hideTimer.stop();
        enterAnim.stop();
        exitAnim.restart();
    }
    // A panel opening takes over the space under the bar.
    on_PanelOpenChanged: if (_panelOpen)
        hide()

    property bool _primed: false
    Connections {
        target: Audio
        function onMonitoredVolumeChanged() {
            if (Audio.monitoredVolume < 0)
                return;
            if (!osd._primed) {
                osd._primed = true;
                return;
            }
            osd.show("volume");
        }
        function onMicMutedChanged() {
            osd.show("mic");
        }
    }
    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: osd.hide()
    }

    property real progress: 0 // 0 = folded into the pill, 1 = full card
    NumberAnimation {
        id: enterAnim
        target: osd
        property: "progress"
        to: 1
        duration: Theme.islandEnterDur
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.springEnter
    }
    NumberAnimation {
        id: exitAnim
        target: osd
        property: "progress"
        to: 0
        duration: Theme.islandExitDur
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.emphExit
    }

    // Full width under the bar, like the island, so the shape and its flares
    // live in screen coordinates.
    anchors { top: true; left: true; right: true }
    margins.top: Theme.barHeight
    implicitHeight: cardHeight
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: shown || progress > 0
    WlrLayershell.namespace: "quickshell-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {} // click-through: feedback, not a control

    // ── The morphing shape ───────────────────────────────────────────────────
    Item {
        id: shape
        readonly property real p: osd.progress
        x: osd._anchorX + (osd.cardX - osd._anchorX) * p
        y: 0
        width: Math.max(0, osd._anchorW + (osd.cardWidth - osd._anchorW) * p)
        height: Math.max(0, osd.cardHeight * p)

        Flare {
            visible: !osd._atLeft
            x: -width
            width: Theme.flareRadius
            height: Theme.flareRadius
            transformOrigin: Item.TopRight
            scale: Math.min(1, shape.p)
            color: Theme.popout
        }
        Flare {
            visible: !osd._atRight
            x: shape.width
            width: Theme.flareRadius
            height: Theme.flareRadius
            mirrored: true
            transformOrigin: Item.TopLeft
            scale: Math.min(1, shape.p)
            color: Theme.popout
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.popout
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: Math.min(Theme.radiusL, height / 2, width / 2)
            bottomRightRadius: Math.min(Theme.radiusL, height / 2, width / 2)
            clip: true // content is laid out at full size; the morph reveals it

            StarField {
                id: starfield
                x: osd.cardX - shape.x
                width: osd.cardWidth
                height: osd.cardHeight
                starCount: Math.max(24, Math.min(120, Math.round(width * height / 1400)))
                maxOpacity: 0.18
                maxRadius: 1.3
            }

            // At its final position (independent of the morph), fading in once
            // the shape has mostly formed.
            RowLayout {
                id: row
                x: osd.cardX - shape.x + Theme.padL
                y: Theme.padL
                width: osd.cardWidth - Theme.padL * 2
                spacing: Theme.gap
                opacity: Math.max(0, Math.min(1, (shape.p - 0.4) / 0.6))
                readonly property bool mic: osd.mode === "mic"
                MIcon {
                    text: row.mic ? (Audio.micMuted ? "mic_off" : "mic") : Audio.volumeIcon(Audio.volume, Audio.muted)
                    size: 20
                    Layout.preferredWidth: 32
                    color: (row.mic ? Audio.micMuted : Audio.muted) ? Theme.surfaceVariantText : Theme.surfaceText
                }
                MSlider {
                    Layout.fillWidth: true
                    value: row.mic ? Audio.micVolume : Audio.volume
                }
                MText {
                    text: Math.round((row.mic ? Audio.micVolume : Audio.volume) * 100) + "%"
                    muted: true
                    sizeDelta: -1
                    Layout.preferredWidth: 34
                    horizontalAlignment: Text.AlignRight
                }
            }
        }
    }
}
