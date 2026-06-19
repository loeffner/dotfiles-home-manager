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

    property bool isOpen: false

    function show() {
        closeAnim.stop();
        isOpen = true;
        visible = true;
        PopupState.opened(pop);
        Qt.callLater(() => {
            if (!isOpen) return;
            openAnim.to = panel.implicitHeight;
            openAnim.start();
        });
    }

    function hide() {
        if (!visible) return;
        isOpen = false;
        openAnim.stop();
        closeAnim.start();
        PopupState.closed(pop);
    }

    function toggle() { visible ? hide() : show(); }

    onVisibleChanged: {
        if (!visible) {
            isOpen = false;
            openAnim.stop();
            closeAnim.stop();
            clipper.height = 0;
            PopupState.closed(pop);
        }
    }

    Item {
        id: clipper
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 0
        clip: true

        // layer.enabled caches content as a GPU texture — no re-render each frame.
        layer.enabled: true

        NumberAnimation {
            id: openAnim; target: clipper; property: "height"
            duration: 150; easing.type: Easing.OutQuart
        }
        NumberAnimation {
            id: closeAnim; target: clipper; property: "height"; to: 0
            duration: 80; easing.type: Easing.InQuart
            onFinished: pop.visible = false
        }

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
