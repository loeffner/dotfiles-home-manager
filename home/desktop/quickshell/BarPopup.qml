import QtQuick
import QtQuick.Layouts
import Quickshell

PopupWindow {
    id: pop

    required property var bar
    required property Item anchorItem
    property int popWidth: 300
    readonly property int cornerR: Theme.flareRadius
    readonly property int totalWidth: popWidth + cornerR * 2

    default property alias content: body.data

    anchor.window: bar
    anchor.rect.x: {
        if (!anchorItem) return 0;
        const centre = anchorItem.mapToItem(bar.contentItem, 0, 0).x
                       + anchorItem.width / 2 - totalWidth / 2;
        return Math.max(4, Math.min(centre, bar.width - totalWidth - 4));
    }
    anchor.rect.y: bar.height

    implicitWidth: totalWidth
    implicitHeight: panel.implicitHeight
    color: "transparent"
    visible: false
    // grabFocus routes pointer events to the popup (so its buttons work) and
    // dismisses on outside click. Without it niri sends clicks elsewhere.
    grabFocus: true

    property bool isOpen: false

    function show() {
        const prev = PopupState.current;
        if (prev && prev !== pop) {
            // Switching popups: drop the previous one's focus grab *now* and open
            // ours on the next tick. Taking a new grab while the old one is still
            // active races at the compositor and flickers the new popup shut.
            prev.hideInstant();
            Qt.callLater(_doShow);
        } else {
            _doShow();
        }
    }
    function _doShow() {
        isOpen = true;
        visible = true;
        PopupState.opened(pop);
    }

    function hide() {
        if (!visible) return;
        isOpen = false;
        PopupState.closed(pop);
        // visible=false is set once the collapse animation reaches 0.
    }

    // Close without the fold-up animation — used when this popup is being
    // replaced by another so its grab releases before the new one is taken.
    function hideInstant() {
        isOpen = false;
        visible = false;
    }

    function toggle() { visible ? hide() : show(); }

    onVisibleChanged: {
        if (!visible) {
            isOpen = false;
            PopupState.closed(pop);
        }
    }

    Item {
        id: clipper
        anchors { top: parent.top; left: parent.left; right: parent.right }
        clip: true

        // layer.enabled caches content as a GPU texture — no re-render each frame.
        layer.enabled: true

        // Track the panel height while open, so content that grows after opening
        // (e.g. expanding a notification group) enlarges the popup instead of
        // being clipped; collapse to 0 when closing. Behavior animates both ways.
        height: pop.isOpen ? panel.implicitHeight : 0
        Behavior on height {
            NumberAnimation {
                duration: pop.isOpen ? 150 : 80
                easing.type: pop.isOpen ? Easing.OutQuart : Easing.InQuart
            }
        }
        onHeightChanged: if (!pop.isOpen && height === 0) pop.visible = false

        Rectangle {
            id: panel
            anchors { top: parent.top; left: parent.left; right: parent.right }
            anchors { leftMargin: pop.cornerR; rightMargin: pop.cornerR }
            implicitHeight: body.implicitHeight + Theme.pad * 2
            color: Theme.bar
            bottomLeftRadius: Theme.radius
            bottomRightRadius: Theme.radius

            ConcaveCorner {
                leftSide: true; radiusPx: pop.cornerR
                anchors { right: parent.left; top: parent.top }
            }
            ConcaveCorner {
                leftSide: false; radiusPx: pop.cornerR
                anchors { left: parent.right; top: parent.top }
            }

            ColumnLayout {
                id: body
                anchors { fill: parent; margins: Theme.pad }
                spacing: Theme.gap
            }
        }
    }
}
