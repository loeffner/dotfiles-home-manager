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
                // modelData is a plain history entry; the live Notification is
                // only reachable via its id, so a closed notification can never
                // dangle in the model.
                readonly property var btns: Notifications.actionsFor(modelData.id)

                Layout.fillWidth: true
                implicitHeight: card.implicitHeight

                function invokeDefault() {
                    const n = Notifications.liveFor(modelData.id);
                    for (const a of (n && n.actions) || [])
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
                    radius: Theme.radiusL
                    color: Theme.surface
                    border.width: 1
                    border.color: toast.critical ? Theme.urgent : Theme.outline

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
                        onFinished: { const id = toast.modelData.id; Qt.callLater(() => Notifications.removeToast(id)); }
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
                                color: Theme.surfaceVariantText
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
                                    color: Theme.surfaceText
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize
                                    font.bold: true
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: "󰅖"
                                    color: closeMa.containsMouse ? Theme.urgent : Theme.surfaceVariantText
                                    font.family: Theme.font
                                    font.pixelSize: Theme.fontSize
                                    Behavior on color { ColorAnimation { duration: 80 } }
                                    MouseArea {
                                        id: closeMa
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: { const id = toast.modelData.id; Qt.callLater(() => Notifications.removeToast(id)); }
                                    }
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: (toast.modelData.body ?? "") !== ""
                                text: toast.modelData.body
                                color: Theme.surfaceVariantText
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
                                        radius: Theme.radiusS
                                        color: aMa.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                                        Behavior on color { ColorAnimation { duration: 80 } }
                                        Text {
                                            id: aLabel
                                            anchors.centerIn: parent
                                            text: modelData.text
                                            color: Theme.surfaceText
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

                    // Auto-dismiss non-critical toasts after the app's configured
                    // on-screen time (Notifications.timeoutFor; -1 = never, so the
                    // timer stays off and the toast persists until dismissed).
                    Timer {
                        readonly property int secs: Notifications.timeoutFor(toast.modelData.appName, toast.critical)
                        interval: secs > 0 ? secs * 1000 : 5000
                        running: secs >= 0
                        repeat: false
                        onTriggered: { const id = toast.modelData.id; Qt.callLater(() => Notifications.removeToast(id)); }
                    }
                }
            }
        }
    }
}
