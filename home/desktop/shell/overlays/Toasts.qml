// On-screen notification toasts: a top-right stack (one per screen). Each shows
// the icon / image, summary + body and action buttons; it auto-dismisses after
// its app's on-screen time (-1 = stays), can be swiped away, and a click jumps to
// the app's window (falling back to the notification's default action).
// Reserves no space.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components
import qs.services

PanelWindow {
    id: win
    required property var modelData
    screen: modelData

    anchors { top: true; right: true }
    margins { top: Theme.barHeight + 8; right: 8 }
    implicitWidth: 380
    implicitHeight: Math.max(1, col.implicitHeight)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: Notifications.toasts.length > 0

    ColumnLayout {
        id: col
        anchors.fill: parent
        spacing: Theme.gap

        Repeater {
            model: ScriptModel {
                objectProp: "id"
                values: Notifications.toasts
            }

            // The layout positions this wrapper; the card slides inside it.
            delegate: Item {
                id: toast
                required property var modelData
                readonly property bool critical: Notifications.isCritical(modelData)
                readonly property var actions: Notifications.actionsFor(modelData.id)
                Layout.fillWidth: true
                implicitHeight: card.implicitHeight

                function dismiss() {
                    const id = modelData.id;
                    Qt.callLater(() => Notifications.dismissToast(id));
                }
                // Jump to the app; only fall back to the default action when no
                // window matched (e.g. a background daemon).
                function activate() {
                    if (!Niri.focusByApp(modelData.desktopEntry, modelData.appName))
                        Notifications.invokeDefault(modelData.id);
                    dismiss();
                }

                // An in-place update (replaces_id) hands the same id a fresh entry:
                // resurface it â restart the timer and replay the slide-in.
                onModelDataChanged: {
                    life.restart();
                    card.opacity = 0;
                    slide.x = 24;
                    appear.restart();
                }

                Rectangle {
                    id: card
                    width: parent.width
                    implicitHeight: body.implicitHeight + Theme.pad * 2
                    radius: Theme.radiusL
                    color: Theme.surface
                    border.width: 1
                    border.color: toast.critical ? Theme.urgent : Theme.outline

                    opacity: 0
                    transform: Translate { id: slide; x: 24 }
                    Component.onCompleted: appear.start()
                    ParallelAnimation {
                        id: appear
                        NumberAnimation { target: card; property: "opacity"; to: 1; duration: 120; easing.type: Easing.OutQuart }
                        NumberAnimation { target: slide; property: "x"; to: 0; duration: 120; easing.type: Easing.OutQuart }
                    }

                    // Swipe / tap (declared first, so the buttons get their own clicks).
                    MouseArea {
                        anchors.fill: parent
                        preventStealing: true
                        cursorShape: Qt.PointingHandCursor
                        property real startX: 0
                        property bool dragging: false
                        property bool committed: false
                        onPressed: e => {
                            startX = mapToItem(toast, e.x, 0).x;
                            dragging = false;
                            committed = false;
                        }
                        onPositionChanged: e => {
                            if (committed)
                                return;
                            const dx = mapToItem(toast, e.x, 0).x - startX;
                            if (Math.abs(dx) > 4)
                                dragging = true;
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
                            if (!dragging)
                                toast.activate();
                            else
                                snapBack.start();
                        }
                    }
                    NumberAnimation {
                        id: fling
                        target: card
                        property: "x"
                        duration: 140
                        easing.type: Easing.InQuart
                        onFinished: toast.dismiss() // deferred: never destroy inside our own callback
                    }
                    NumberAnimation {
                        id: snapBack
                        target: card
                        property: "x"
                        to: 0
                        duration: 120
                        easing.type: Easing.OutQuart
                        onStarted: card.opacity = 1
                    }

                    RowLayout {
                        id: body
                        anchors { fill: parent; margins: Theme.pad }
                        spacing: Theme.gap

                        Item {
                            Layout.alignment: Qt.AlignTop
                            implicitWidth: 32
                            implicitHeight: 32
                            Image {
                                id: icon
                                anchors.fill: parent
                                source: Notifications.iconSource(toast.modelData)
                                sourceSize: Qt.size(32, 32)
                                fillMode: Image.PreserveAspectFit
                                visible: status === Image.Ready
                            }
                            MText {
                                anchors.centerIn: parent
                                visible: icon.status !== Image.Ready
                                text: "󰂚" // nf-md-bell
                                muted: true
                                font.pixelSize: Theme.iconSize + 4
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            RowLayout {
                                Layout.fillWidth: true
                                MText {
                                    Layout.fillWidth: true
                                    text: (toast.modelData.appName ? toast.modelData.appName + ":  " : "") + toast.modelData.summary
                                    font.bold: true
                                    elide: Text.ElideRight
                                }
                                MText {
                                    text: "󰅖" // nf-md-close
                                    color: closeMa.containsMouse ? Theme.urgent : Theme.surfaceVariantText
                                    Behavior on color { ColorAnimation { duration: 80 } }
                                    MouseArea {
                                        id: closeMa
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: toast.dismiss()
                                    }
                                }
                            }
                            MText {
                                Layout.fillWidth: true
                                visible: (toast.modelData.body ?? "") !== ""
                                text: toast.modelData.body
                                muted: true
                                wrapMode: Text.WordWrap
                                textFormat: Text.PlainText // a stranger's text: markup could fetch remote images
                            }
                            Flow {
                                Layout.fillWidth: true
                                Layout.topMargin: 2
                                visible: toast.actions.length > 0
                                spacing: Theme.gap
                                Repeater {
                                    model: toast.actions
                                    delegate: Rectangle {
                                        required property var modelData
                                        implicitWidth: aLabel.implicitWidth + Theme.pad * 2
                                        implicitHeight: aLabel.implicitHeight + Theme.gap
                                        radius: Theme.radiusS
                                        color: aMa.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                                        Behavior on color { ColorAnimation { duration: 80 } }
                                        MText {
                                            id: aLabel
                                            anchors.centerIn: parent
                                            text: parent.modelData.text
                                            sizeDelta: -1
                                        }
                                        MouseArea {
                                            id: aMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                parent.modelData.invoke();
                                                toast.dismiss();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Auto-dismiss after the app's on-screen time (-1 = never).
                    Timer {
                        id: life
                        readonly property int secs: Notifications.timeoutFor(toast.modelData.appName, toast.critical)
                        interval: secs > 0 ? secs * 1000 : 5000
                        running: secs >= 0
                        onTriggered: toast.dismiss()
                    }
                }
            }
        }
    }
}
