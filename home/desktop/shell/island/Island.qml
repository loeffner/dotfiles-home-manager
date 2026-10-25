// Island — the popout surface of one screen: the bar itself extending downward
// (dynamic-island style) to host whichever panel Popouts has open there.
//
// The shape is the bar's colour, borderless, flush under the bar, joined to it by
// concave flares, with only its bottom corners rounded. Opening morphs it out of
// the trigger (from the anchor's width and zero height, spring overshoot);
// switching panels morphs it from one panel's rect to the next while the content
// crossfades; closing folds it back into the anchor. A panel that would land
// within a flare's width of the screen edge snaps flush to it (that side's flare
// is dropped).
//
// Every panel is instantiated once and kept (state such as tabs and filters
// survives between opens); only the open one is visible. While open the window
// holds EXCLUSIVE keyboard focus: Escape closes, text fields focus on the first
// click, and — unlike OnDemand — niri never turns a click into a focus transfer,
// so one click anywhere outside dismisses. The window starts below the bar, so
// bar clicks (another icon → switch panels) land directly.
//
// Usage (one per screen): Variants { model: Quickshell.screens; Island { SomePanel {} } }
// Everything keys off `modelData` (the screen this island was created for), never
// the window's `screen` property, which re-notifies when the window maps — a
// binding on it re-entered itself while opening.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

PanelWindow {
    id: win
    required property var modelData
    default property alias panels: holder.data

    screen: modelData
    readonly property string openId: Popouts.current(modelData)
    // Whether the compositor has given this surface keyboard focus.
    readonly property bool hasKeyboard: holder.Window.active
    // The panel on screen — still set while folding away after a close.
    readonly property var panel: _find(_shownId)

    anchors { top: true; bottom: true; left: true; right: true }
    margins.top: Theme.barHeight
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: _alive
    WlrLayershell.namespace: "quickshell-island"
    WlrLayershell.keyboardFocus: openId !== "" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function _find(id) {
        for (const p of holder.children)
            if (p.panelId === id)
                return p;
        return null;
    }
    function close() {
        Popouts.close(modelData);
    }

    // ── Geometry ─────────────────────────────────────────────────────────────
    // The anchor rect (where the morph starts / ends) is measured when a panel
    // opens: mapToItem() isn't reactive, so a binding would freeze at its
    // pre-layout position.
    property real _anchorX: 0
    property real _anchorW: 0
    // Target rect of the open panel.
    property real _targetX: 0
    property real _targetW: 0
    readonly property real _targetH: panel ? panel.contentHeight : 0
    property bool _atLeft: false
    property bool _atRight: false

    function _measure() {
        const a = Popouts.anchorOf(modelData);
        if (a) {
            _anchorX = a.mapToItem(null, 0, 0).x;
            _anchorW = a.width;
        }
        if (panel) {
            // The screen width, not the window's: before the first map the window
            // is 0 wide and everything would snap to the right edge.
            const sw = modelData.width;
            const w = panel.panelWidth;
            const want = _anchorX + _anchorW / 2 - w / 2;
            _atLeft = want < Theme.flareRadius;
            _atRight = want > sw - w - Theme.flareRadius;
            _targetX = _atRight ? sw - w : _atLeft ? 0 : want;
            _targetW = w;
        }
    }

    // A panel can change width while open (the clock panel grows a media box).
    Connections {
        target: win.panel
        function onPanelWidthChanged() {
            win._measure();
        }
    }

    // ── Open / switch / close ────────────────────────────────────────────────
    property bool _alive: false
    property real progress: 0 // 0 = folded into the anchor, 1 = full panel
    property bool _settled: false // open and not morphing in/out
    property string _shownId: "" // panel whose content is visible (lags on close)

    onOpenIdChanged: {
        if (openId === "") {
            if (_alive) {
                _settled = false;
                enterAnim.stop();
                exitAnim.restart();
            }
        } else if (_alive && !exitAnim.running) {
            // Switch: tween the shape from the current panel's rect to the new one.
            _settled = true;
            _shownId = openId;
            _measure();
        } else {
            // Open (or re-open while folding away): morph out of the anchor.
            _settled = false;
            _shownId = openId;
            _measure();
            _alive = true;
            exitAnim.stop();
            enterAnim.restart();
        }
    }

    NumberAnimation {
        id: enterAnim
        target: win
        property: "progress"
        to: 1
        duration: Theme.islandEnterDur
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.springEnter
        onFinished: win._settled = true
    }
    NumberAnimation {
        id: exitAnim
        target: win
        property: "progress"
        to: 0
        duration: Theme.islandExitDur
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.emphExit
        onFinished: {
            win._alive = false;
            win._shownId = "";
        }
    }

    // Shown rect: tweened between panels and on in-place resizes once settled.
    property real shownX: _targetX
    property real shownW: _targetW
    property real shownH: _targetH
    Behavior on shownX {
        enabled: win._settled
        NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic }
    }
    Behavior on shownW {
        enabled: win._settled
        NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic }
    }
    Behavior on shownH {
        enabled: win._settled
        NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic }
    }

    // Click anywhere outside the shape to dismiss.
    MouseArea {
        anchors.fill: parent
        onClicked: win.close()
    }

    // ── The morphing shape ───────────────────────────────────────────────────
    Item {
        id: shape
        readonly property real p: win.progress
        x: win._anchorX + (win.shownX - win._anchorX) * p
        y: 0
        width: Math.max(0, win._anchorW + (win.shownW - win._anchorW) * p)
        height: Math.max(0, win.shownH * p)

        // The surface's default focus item and an ancestor of every field, so
        // Escape lands here directly or propagates up from a field that doesn't
        // consume it (MTextField.consumeEscape).
        focus: true
        Keys.onEscapePressed: win.close()

        Flare {
            visible: !win._atLeft
            x: -width
            width: Theme.flareRadius
            height: Theme.flareRadius
            transformOrigin: Item.TopRight
            scale: Math.min(1, shape.p)
            color: Theme.popout
        }
        Flare {
            visible: !win._atRight
            x: shape.width
            width: Theme.flareRadius
            height: Theme.flareRadius
            mirrored: true
            transformOrigin: Item.TopLeft
            scale: Math.min(1, shape.p)
            color: Theme.popout
        }

        Rectangle {
            id: card
            anchors.fill: parent
            color: Theme.popout
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: Math.min(Theme.radiusL, height / 2, width / 2)
            bottomRightRadius: Math.min(Theme.radiusL, height / 2, width / 2)
            clip: true // content is laid out at full size; the morph reveals it

            // Swallow clicks so panel controls don't reach the backdrop.
            MouseArea { anchors.fill: parent }

            // Backdrop starfield, re-scattered on every open.
            StarField {
                id: starfield
                x: win.shownX - shape.x
                width: win.shownW
                height: win.shownH
                starCount: Math.max(24, Math.min(120, Math.round(width * height / 1400)))
                maxOpacity: 0.18
                maxRadius: 1.3
                Connections {
                    target: win
                    function on_AliveChanged() {
                        if (win._alive)
                            starfield.seed = Math.floor(Math.random() * 2147483647);
                    }
                }
            }

            // All panels live here at their final position (independent of the
            // morph, so layouts don't re-flow every frame); only the shown one
            // is visible, fading in once the shape has mostly formed.
            Item {
                id: holder
                x: win.shownX - shape.x
                width: win.shownW
                height: win.shownH
                opacity: Math.max(0, Math.min(1, (shape.p - 0.4) / 0.6))

                // Wire every panel, including ones added after startup.
                function wire() {
                    for (const p of holder.children) {
                        p.screen = Qt.binding(() => win.modelData);
                        p.shown = Qt.binding(() => p.panelId === win._shownId);
                    }
                }
                Component.onCompleted: wire()
                onChildrenChanged: wire()
            }
        }
    }
}
