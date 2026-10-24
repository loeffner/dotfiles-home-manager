// Popout — the Material-3 dropdown for the DMS-grade cluster (the shell's single
// popup framework; replaced the retired BarPopup).
//
// Drawn as the bar itself extending downward (dynamic-island style): the shape is
// the bar's colour, borderless, flush under the bar, joined to it by concave
// flares (Flare.qml) with only its bottom corners rounded. Opening morphs the
// shape out of the trigger icon — from the icon's width and zero height to the
// full card, with a spring overshoot — and the content fades in once the shape
// has mostly formed; closing runs the morph back into the icon. A popout that
// would land within a flare's width of the screen edge snaps flush to it instead
// (that side's flare is dropped), so it reads as the bar's end turning down.
//
// A transparent, full-width layershell window that starts *below the bar* (so the
// bar strip stays live and clickable). Its backdrop MouseArea is the click-outside
// dismiss. Every popout holds EXCLUSIVE keyboard focus while open (see win), so all
// of them behave alike: Escape closes, text fields focus on the first click, and
// one click anywhere behaves like DankMaterialShell — click another icon and the
// shared PopoutManager closes this one and opens that one in the same click; click
// empty space and it just closes. Open/close is driven entirely by
// PopoutManager.openId.
//
// Usage: `Popout { id: pop; bar: root.bar; anchorItem: root; popId: "audio";
// popWidth: N; ...content... }` and call pop.toggle().
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

Item {
    id: root
    required property var bar // the bar PanelWindow (screen + x mapping)
    required property Item anchorItem // trigger to centre the card under
    required property string popId // unique id for the shared PopoutManager
    property int popWidth: 360

    default property alias content: body.data

    implicitWidth: 0
    implicitHeight: 0

    readonly property bool isOpen: PopoutManager.openId === popId
    // Kept true while the window must stay mapped — open, or still animating out.
    property bool _alive: false
    // Morph progress: 0 = collapsed into the trigger, 1 = full card (the spring
    // overshoots slightly past 1).
    property real progress: 0
    // True once the enter morph has finished — gates the height Behavior so it
    // only smooths in-place resizes (e.g. a section expanding), not the morph.
    property bool _settled: false

    function open() {
        PopoutManager.open(popId);
    }
    function close() {
        if (PopoutManager.openId === popId)
            PopoutManager.close();
    }
    function toggle() {
        PopoutManager.toggle(popId);
    }

    onIsOpenChanged: {
        _settled = false;
        if (isOpen) {
            // mapToItem() isn't reactive, so measure the trigger on every open
            // (a binding would freeze at its pre-layout position).
            if (anchorItem && bar) {
                _anchorX = anchorItem.mapToItem(bar.contentItem, 0, 0).x;
                _anchorW = anchorItem.width;
            }
            // Re-scatter the backdrop starfield on every open.
            starfield.seed = Math.floor(Math.random() * 2147483647);
            _alive = true;
            exitAnim.stop();
            enterAnim.restart();
        } else if (_alive) {
            enterAnim.stop();
            exitAnim.restart();
        }
    }

    NumberAnimation {
        id: enterAnim
        target: root
        property: "progress"
        to: 1
        duration: Theme.islandEnterDur
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.springEnter
        onFinished: root._settled = true
    }
    NumberAnimation {
        id: exitAnim
        target: root
        property: "progress"
        to: 0
        duration: Theme.islandExitDur
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.emphExit
        onFinished: root._alive = false
    }

    // ── Geometry (bar coordinates) ───────────────────────────────────────────
    // Trigger rect — where the morph starts and ends. Set on open (see onIsOpenChanged).
    property real _anchorX: 0
    property real _anchorW: 0
    // Card x: trigger centre, snapped flush to a screen edge when it would land
    // closer to it than a flare is wide.
    readonly property real _wantX: _anchorX + _anchorW / 2 - popWidth / 2
    readonly property bool _atLeft: !!bar && _wantX < Theme.flareRadius
    readonly property bool _atRight: !!bar && _wantX > bar.width - popWidth - Theme.flareRadius
    readonly property real cardX: !bar ? 0 : _atRight ? bar.width - popWidth : _atLeft ? 0 : _wantX
    readonly property real _fullH: body.implicitHeight + Theme.padL * 2

    PanelWindow {
        id: win
        screen: root.bar ? root.bar.screen : null
        // Full width, starting just below the bar so the bar stays interactive.
        anchors { top: true; bottom: true; left: true; right: true }
        margins.top: Theme.barHeight
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        visible: root._alive

        // Keyboard focus for the whole open life. EXCLUSIVE (like DMS on niri):
        // unlike OnDemand, an exclusive grab means niri never transfers focus on a
        // click — so dismiss clicks land on the first try everywhere, and fields
        // can be focused on map (type immediately). niri still handles its own
        // keybinds.
        WlrLayershell.keyboardFocus: root.isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // Click anywhere outside the card to dismiss.
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        // ── The morphing shape ──────────────────────────────────────────────
        Item {
            id: shape
            readonly property real p: root.progress
            x: root._anchorX + (root.cardX - root._anchorX) * p
            y: 0
            width: Math.max(0, root._anchorW + (root.popWidth - root._anchorW) * p)
            height: Math.max(0, shownH * p)
            // Full card height, smoothed for in-place resizes once settled.
            property real shownH: root._fullH
            Behavior on shownH {
                enabled: root._settled
                NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic }
            }

            // Default focus item of the surface, and an ancestor of every field in
            // the card — so Escape lands here either directly or by propagating up
            // from a field that doesn't consume it (MTextField.consumeEscape).
            focus: true
            Keys.onEscapePressed: root.close()

            // Concave shoulders joining the shape to the bar. Scaled in with the
            // morph from the corner where they touch the shape.
            Flare {
                visible: !root._atLeft
                x: -width
                width: Theme.flareRadius
                height: Theme.flareRadius
                transformOrigin: Item.TopRight
                scale: Math.min(1, shape.p)
                color: Theme.popout
            }
            Flare {
                visible: !root._atRight
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
                clip: true // the content is laid out at full size; the morph reveals it

                // Swallow clicks so card controls don't reach the backdrop.
                MouseArea { anchors.fill: parent }

                // Content at its final position and size, independent of the morph
                // (so neither the layout nor the starfield re-flow every frame).
                Item {
                    x: root.cardX - shape.x
                    width: root.popWidth
                    height: root._fullH
                    opacity: Math.max(0, Math.min(1, (shape.p - 0.4) / 0.6))

                    // Subtle starfield backdrop, re-scattered each open (see onIsOpenChanged).
                    StarField {
                        id: starfield
                        anchors.fill: parent
                        starCount: Math.max(24, Math.min(120, Math.round(width * height / 1400)))
                        maxOpacity: 0.18
                        maxRadius: 1.3
                    }

                    ColumnLayout {
                        id: body
                        anchors { fill: parent; margins: Theme.padL }
                        spacing: Theme.gapL
                    }
                }
            }
        }
    }
}
