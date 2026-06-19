// On-screen toasts: a top-right overlay (one per screen) that stacks tracked
// notifications and auto-dismisses each after its timeout. Critical ones stay
// until dismissed. Does not reserve screen space (ExclusionMode.Ignore).
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
    visible: Notifications.list.values.length > 0

    ColumnLayout {
        id: col
        anchors.fill: parent
        spacing: Theme.gap

        Repeater {
            model: Notifications.list

            delegate: Rectangle {
                id: toast
                required property var modelData
                readonly property bool critical: modelData.urgency === NotificationUrgency.Critical

                Layout.fillWidth: true
                implicitHeight: body.implicitHeight + Theme.pad * 2
                radius: Theme.radius
                color: Theme.bgPopup
                border.width: 1
                border.color: critical ? Theme.urgent : Theme.border

                // Slide + fade in on arrival.
                opacity: 0
                transform: Translate {
                    id: slide
                    x: 24
                }
                Component.onCompleted: appear.start()
                ParallelAnimation {
                    id: appear
                    NumberAnimation {
                        target: toast
                        property: "opacity"
                        to: 1
                        duration: 120
                        easing.type: Easing.OutQuart
                    }
                    NumberAnimation {
                        target: slide
                        property: "x"
                        to: 0
                        duration: 120
                        easing.type: Easing.OutQuart
                    }
                }

                ColumnLayout {
                    id: body
                    anchors {
                        fill: parent
                        margins: Theme.pad
                    }
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
                            color: Theme.dim
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: toast.modelData.dismiss()
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
                }

                // Auto-dismiss non-critical toasts. expireTimeout is in ms; <=0
                // means "unspecified", so fall back to 5s.
                Timer {
                    interval: toast.modelData.expireTimeout > 0 ? toast.modelData.expireTimeout : 5000
                    running: !toast.critical
                    repeat: false
                    onTriggered: toast.modelData.dismiss()
                }
            }
        }
    }
}
