// Popout — the Material-3 dropdown for the DMS-grade cluster (the shell's single
// popup framework; replaced the retired BarPopup).
//
// A transparent, full-width layershell window that starts *below the bar* (so the
// bar strip stays live and clickable). Its backdrop MouseArea is the click-outside
// dismiss. It deliberately takes NO keyboard focus: grabbing focus made the first
// click on the bar merely transfer focus (a two-click dismiss); without it, one
// click anywhere behaves like DankMaterialShell — click another icon and the
// shared PopoutManager closes this one and opens that one in the same click; click
// empty space and it just closes. Escape is handled by the bar (which holds the
// keyboard focus). Open/close is driven entirely by PopoutManager.openId, and the
// card animates with DMS's spring-overshoot enter / emphasized exit.
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
    // Opt-in keyboard focus for text fields (search, Wi-Fi password). Off by
    // default so dismiss clicks never hit niri's focus-transfer dance.
    //   • keyboardOnOpen: the popout is keyboard-focusable for its whole open
    //     life (so a text field focuses on the FIRST click / auto-focus works).
    //     Set this for popouts that contain a text field.
    //   • wantsFocus: a field flips this while being edited (used when the popout
    //     is otherwise focus-free).
    property bool keyboardOnOpen: false
    property bool wantsFocus: false

    default property alias content: body.data

    implicitWidth: 0
    implicitHeight: 0

    readonly property bool isOpen: PopoutManager.openId === popId
    // Kept true while the window must stay mapped — open, or still animating out.
    property bool _alive: false

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
        if (isOpen) {
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

    // x of the card within the screen-wide window: trigger centre, clamped.
    readonly property real cardX: {
        if (!anchorItem || !bar)
            return 8;
        const c = anchorItem.mapToItem(bar.contentItem, 0, 0).x + anchorItem.width / 2 - popWidth / 2;
        return Math.max(8, Math.min(c, bar.width - popWidth - 8));
    }

    PanelWindow {
        id: win
        screen: root.bar ? root.bar.screen : null
        // Full width, starting just below the bar so the bar stays interactive.
        anchors { top: true; bottom: true; left: true; right: true }
        margins.top: Theme.barHeight
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        visible: root._alive

        // Keyboard focus while a field asks for it, or the whole time for popouts
        // that declare keyboardOnOpen. Uses EXCLUSIVE (like DMS on niri): unlike
        // OnDemand, an exclusive grab means niri never transfers focus on a click
        // — so dismiss clicks land on the first try everywhere, and the field is
        // focused on map (type immediately). niri still handles its own keybinds.
        WlrLayershell.keyboardFocus: (root.isOpen && (root.wantsFocus || root.keyboardOnOpen)) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // Click anywhere outside the card to dismiss.
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        // ── The animated card ───────────────────────────────────────────────
        Item {
            id: cardWrap
            x: root.cardX
            y: 0
            width: card.width
            height: card.height
            transformOrigin: Item.Top
            opacity: 0
            scale: Theme.scaleCollapsed
            transform: Translate { id: tr; y: Theme.animOffset }

            ParallelAnimation {
                id: enterAnim
                NumberAnimation { target: cardWrap; property: "opacity"; to: 1; duration: Theme.popoutDur; easing.type: Easing.OutCubic }
                NumberAnimation { target: cardWrap; property: "scale"; to: 1; duration: Theme.popoutDur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springEnter }
                NumberAnimation { target: tr; property: "y"; to: 0; duration: Theme.popoutDur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springEnter }
            }
            ParallelAnimation {
                id: exitAnim
                NumberAnimation { target: cardWrap; property: "opacity"; to: 0; duration: Theme.popoutDur; easing.type: Easing.OutCubic }
                NumberAnimation { target: cardWrap; property: "scale"; to: Theme.scaleCollapsed; duration: Theme.popoutDur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphExit }
                NumberAnimation { target: tr; property: "y"; to: Theme.animOffset; duration: Theme.popoutDur; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.emphExit }
                onFinished: root._alive = false
            }

            Rectangle {
                id: card
                width: root.popWidth
                implicitHeight: body.implicitHeight + Theme.padL * 2
                height: implicitHeight
                radius: Theme.radiusL
                color: Theme.surface
                border.width: 1
                border.color: Theme.outline
                clip: true // keep the starfield inside the rounded corners

                // Subtle starfield backdrop, re-scattered each open (see onIsOpenChanged).
                StarField {
                    id: starfield
                    anchors.fill: parent
                    starCount: Math.max(24, Math.min(120, Math.round(width * height / 1400)))
                    maxOpacity: 0.18
                    maxRadius: 1.3
                }

                // Swallow clicks so card controls don't reach the backdrop.
                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    id: body
                    anchors { fill: parent; margins: Theme.padL }
                    spacing: Theme.gapL
                }
            }
        }
    }
}
