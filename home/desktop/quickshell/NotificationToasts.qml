// On-screen toasts: a top-right overlay (one per screen) that stacks tracked
// notifications. Each toast shows the app icon/image, summary + body, any action
// buttons, auto-dismisses after its timeout (critical ones stay), can be swiped
// horizontally to dismiss, and invokes the default action when clicked. Does not
// reserve screen space (ExclusionMode.Ignore).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

PanelWindow {
    id: win
    required property var modelData
    screen: modelData

    anchors {
        top: true
        right: true
    }
    margins {
        top: Theme.barHeight + 8
        right: 8
    }
    implicitWidth: 380
    implicitHeight: Math.max(1, col.implicitHeight)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: Notifications.toastQueue.length > 0

    ColumnLayout {
        id: col
        anchors.fill: parent
        spacing: Theme.gap

        Repeater {
            model: Notifications.toastQueue

            // Wrapper: the layout positions this; the card inside slides freely
            // for the swipe gesture.
            delegate: Item {
                id: toast
                required property var modelData
                readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
                // Visible action buttons (skip the implicit "default" action).
                readonly property var btns: (modelData.actions || []).filter(a => a.identifier !== "default" && (a.text ?? "") !== "")

                Layout.fillWidth: true
                implicitHeight: card.implicitHeight

                function invokeDefault() {
                    for (const a of (modelData.actions || []))
                        if (a.identifier === "default") { a.invoke(); return true; }
                    return false;
                }

                // Clicking the toast should jump to the app that raised it; only
                // fall back to the notification's own default action if no window
                // matched (e.g. a background daemon with no window).
                function activate() {
                    if (!Niri.focusByApp(modelData.desktopEntry, modelData.appName))
                        invokeDefault();
                }

                Rectangle {
                    id: card
                    width: parent.width
                    implicitHeight: body.implicitHeight + Theme.pad * 2
                    radius: Theme.radius
                    color: Theme.bgPopup
                    border.width: 1
                    border.color: toast.critical ? Theme.urgent : Theme.border

                    // Slide + fade in on arrival; fade with swipe distance.
                    opacity: 0
                    transform: Translate { id: slide; x: 24 }
                    Component.onCompleted: appear.start()
                    ParallelAnimation {
                        id: appear
                        NumberAnimation { target: card; property: "opacity"; to: 1; duration: 120; easing.type: Easing.OutQuart }
                        NumberAnimation { target: slide; property: "x"; to: 0; duration: 120; easing.type: Easing.OutQuart }
                    }

                    // Swipe handling (declared first so the buttons above receive
                    // their own clicks; this catches drags/taps on the rest).
                    MouseArea {
                        id: swipe
                        anchors.fill: parent
                        preventStealing: true
                        property real startX: 0
                        property bool dragging: false
                        property bool committed: false
                        cursorShape: Qt.PointingHandCursor
                        onPressed: e => { startX = mapToItem(toast, e.x, 0).x; dragging = false; committed = false; }
                        onPositionChanged: e => {
                            if (committed) return;
                            const dx = mapToItem(toast, e.x, 0).x - startX;
                            if (Math.abs(dx) > 4) dragging = true;
                            card.x = dx;
                            card.opacity = Math.max(0.15, 1 - Math.abs(dx) / toast.width);
                            // Commit mid-drag so the pointer can leave the surface.
                            if (Math.abs(dx) > 64) {
                                committed = true;
                                fling.to = dx > 0 ? toast.width + 40 : -toast.width - 40;
                                fling.start();
                            }
                        }
                        onReleased: {
                            if (committed)
                                return;
                            if (!dragging) {
                                toast.activate();
                                const n = toast.modelData;
                                Qt.callLater(() => Notifications.removeToast(n));
                            } else {
                                snapBack.start();
                            }
                        }
                    }
                    NumberAnimation {
                        id: fling; target: card; property: "x"; duration: 140; easing.type: Easing.InQuart
                        // Defer: removing from the queue destroys this delegate, which
                        // must not happen inside its own animation callback.
                        onFinished: { const n = toast.modelData; Qt.callLater(() => Notifications.removeToast(n)); }
                    }
                    NumberAnimation {
                        id: snapBack; target: card; property: "x"; to: 0; duration: 120; easing.type: Easing.OutQuart
                        onStarted: card.opacity = 1
                    }

                    RowLayout {
                        id: body
                        anchors { fill: parent; margins: Theme.pad }
                        spacing: Theme.gap

                        // App icon / notification image.
                        Item {
                            Layout.alignment: Qt.AlignTop
                            implicitWidth: 32
                            implicitHeight: 32
                            Image {
                                id: tIcon
                                anchors.fill: parent
                                source: Notifications.iconSource(toast.modelData)
                                sourceSize.width: 32
                                sourceSize.height: 32
                                fillMode: Image.PreserveAspectFit
                                visible: status === Image.Ready
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: tIcon.status !== Image.Ready
                                text: "󰂚"
                                color: Theme.dim
                                font.family: Theme.font
                                font.pixelSize: Theme.iconSize + 4
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true
                                    text: (toast.modelData.appName ? toast.modelData.appName + ":  " : "") + toast.modelData.summary
                                    color: Theme.fg
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize
                                    font.bold: true
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: "󰅖"
                                    color: closeMa.containsMouse ? Theme.urgent : Theme.dim
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize
                                    Behavior on color { ColorAnimation { duration: 80 } }
                                    MouseArea {
                                        id: closeMa
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { const n = toast.modelData; Qt.callLater(() => Notifications.removeToast(n)); }
                                    }
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: (toast.modelData.body ?? "") !== ""
                                text: toast.modelData.body
                                color: Theme.dim
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize
                                wrapMode: Text.WordWrap
                                textFormat: Text.MarkdownText
                            }

                            // Action buttons.
                            Flow {
                                Layout.fillWidth: true
                                Layout.topMargin: 2
                                visible: toast.btns.length > 0
                                spacing: Theme.gap

                                Repeater {
                                    model: toast.btns
                                    delegate: Rectangle {
                                        required property var modelData
                                        implicitWidth: aLabel.implicitWidth + Theme.pad * 2
                                        implicitHeight: aLabel.implicitHeight + Theme.gap
                                        radius: Theme.radius - 4
                                        color: aMa.containsMouse ? Theme.bg2 : Theme.bg1
                                        Behavior on color { ColorAnimation { duration: 80 } }
                                        Text {
                                            id: aLabel
                                            anchors.centerIn: parent
                                            text: modelData.text
                                            color: Theme.fg
                                            font.family: Theme.font
                                            font.pixelSize: Theme.fontSize - 1
                                        }
                                        MouseArea {
                                            id: aMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                modelData.invoke();
                                                const n = toast.modelData;
                                                Qt.callLater(() => Notifications.removeToast(n));
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Auto-dismiss non-critical toasts. expireTimeout is in ms;
                    // <=0 means "unspecified", so fall back to 5s.
                    Timer {
                        interval: toast.modelData.expireTimeout > 0 ? toast.modelData.expireTimeout : 5000
                        running: !toast.critical
                        repeat: false
                        onTriggered: { const n = toast.modelData; Qt.callLater(() => Notifications.removeToast(n)); }
                    }
                }
            }
        }
    }
}
