// Bar clock. Click to open an M3 popout (on the shared Popout framework, like
// the cluster) laid out as three framed boxes over the shared starfield:
// clock (left) · month calendar (centre) · now-playing media (right, when active).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris

Item {
    id: root
    required property var bar
    implicitWidth: label.implicitWidth
    implicitHeight: Theme.barHeight

    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property var player: MediaThumb.active
    readonly property bool hasMedia: player !== null

    Text {
        id: label
        anchors.centerIn: parent
        color: (ma.containsMouse || popup.isOpen) ? Theme.iconHover : Theme.surfaceText
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        text: Qt.formatDateTime(clock.date, "ddd dd MMM   HH:mm")
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    // Hover cue: a subtle grow + accent tint. The scale is a render transform, so
    // it doesn't change the clock's layout width — the flanking notif/media stay
    // put and the clock keeps its fixed centre.
    scale: (ma.containsMouse || popup.isOpen) ? 1.06 : 1.0
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: popup.toggle()
    }

    Popout {
        id: popup
        bar: root.bar
        anchorItem: root
        popId: "clock"
        popWidth: root.hasMedia ? 724 : 500

        // Snap the calendar back to the current month whenever it opens.
        Connections {
            target: popup
            function onIsOpenChanged() {
                if (popup.isOpen) {
                    const n = new Date();
                    cal.year = n.getFullYear();
                    cal.month = n.getMonth();
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gapL

            // ── Clock box ────────────────────────────────────────────────────
            Rectangle {
                Layout.preferredWidth: 150
                Layout.fillHeight: true
                color: "transparent"
                radius: Theme.radiusM
                border.width: 1
                border.color: Theme.outline

                Column {
                    anchors.centerIn: parent
                    spacing: 0

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(clock.date, "HH")
                        color: Theme.primary
                        font { family: Theme.font; pixelSize: 56; bold: true }
                        bottomPadding: -10
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "•••"
                        color: Theme.surfaceVariantText
                        font { family: Theme.font; pixelSize: 16 }
                        topPadding: -10
                        bottomPadding: -10
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(clock.date, "mm")
                        color: Theme.primary
                        font { family: Theme.font; pixelSize: 56; bold: true }
                        topPadding: -10
                        bottomPadding: 10
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(clock.date, "ddd d MMM")
                        color: Theme.surfaceText
                        font { family: Theme.font; pixelSize: Theme.fontSize }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(clock.date, "yyyy")
                        color: Theme.surfaceVariantText
                        font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
                    }
                }
            }

            // ── Calendar box ─────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitWidth: cal.implicitWidth + Theme.padL * 2
                implicitHeight: cal.implicitHeight + Theme.padL * 2
                color: "transparent"
                radius: Theme.radiusM
                border.width: 1
                border.color: Theme.outline

                Calendar {
                    id: cal
                    anchors.centerIn: parent
                    cellSize: 34
                }
            }

            // ── Media box (only while a player is active) ─────────────────────
            Rectangle {
                Layout.preferredWidth: 210
                Layout.fillHeight: true
                visible: root.hasMedia
                color: "transparent"
                radius: Theme.radiusM
                border.width: 1
                border.color: Theme.outline

                ColumnLayout {
                    anchors { fill: parent; margins: Theme.padL }
                    spacing: Theme.gap

                    // Cover art.
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 92
                        implicitHeight: 92
                        radius: Theme.radiusM
                        color: Theme.surfaceContainerHighest
                        clip: true

                        Image {
                            id: dashArt
                            anchors.fill: parent
                            source: MediaThumb.path
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready
                        }
                        MIcon {
                            anchors.centerIn: parent
                            visible: dashArt.status !== Image.Ready
                            text: "music_note"
                            size: 34
                            color: Theme.surfaceVariantText
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.player?.trackTitle ?? ""
                        color: Theme.surfaceText
                        font { family: Theme.font; pixelSize: Theme.fontSize; bold: true }
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.player?.trackArtist ?? ""
                        color: Theme.surfaceVariantText
                        font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                    }

                    // Transport controls.
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        spacing: Theme.gap
                        MIconButton {
                            icon: "skip_previous"
                            size: 22
                            enabled: root.player?.canGoPrevious ?? false
                            opacity: enabled ? 1 : 0.4
                            onClicked: MediaThumb.previousOrRewind()
                        }
                        MIconButton {
                            icon: root.player?.playbackState === MprisPlaybackState.Playing ? "pause" : "play_arrow"
                            size: 26
                            implicitWidth: 44
                            implicitHeight: 44
                            raised: true
                            onClicked: root.player?.togglePlaying()
                        }
                        MIconButton {
                            icon: "skip_next"
                            size: 22
                            enabled: root.player?.canGoNext ?? false
                            opacity: enabled ? 1 : 0.4
                            onClicked: root.player?.next()
                        }
                    }

                    // Jump to the playing app.
                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: openRow.implicitWidth
                        implicitHeight: openRow.implicitHeight
                        visible: root.player?.canRaise ?? false

                        RowLayout {
                            id: openRow
                            anchors.fill: parent
                            spacing: Theme.gap / 2
                            MIcon {
                                text: "open_in_new"
                                size: 16
                                color: Theme.primary
                            }
                            Text {
                                text: root.player?.identity ?? "Open"
                                color: Theme.primary
                                font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
                                elide: Text.ElideRight
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.player?.raise();
                                popup.close();
                            }
                        }
                    }
                }
            }
        }
    }
}
