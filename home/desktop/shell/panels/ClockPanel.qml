// Clock panel ("clock"): three outline-framed boxes — a big vertical clock, the
// month calendar (snapped back to this month on every open), and now-playing
// media (cover, title, artist, transport, jump to the player) while a player
// exists. Widens when the media box is shown.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import qs.config
import qs.components
import qs.island
import qs.services

IslandPanel {
    id: root
    panelId: "clock"
    readonly property var player: Player.active
    panelWidth: player ? 724 : 500

    onOpened: cal.reset()

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    component Box: Rectangle {
        Layout.fillHeight: true
        color: "transparent"
        radius: Theme.radiusM
        border.width: 1
        border.color: Theme.outline
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.gapL

        Box {
            Layout.preferredWidth: 150
            Column {
                anchors.centerIn: parent
                MText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "HH")
                    color: Theme.primary
                    font.pixelSize: 56
                    font.bold: true
                    bottomPadding: -10
                }
                MText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "•••"
                    muted: true
                    font.pixelSize: 16
                    topPadding: -10
                    bottomPadding: -10
                }
                MText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "mm")
                    color: Theme.primary
                    font.pixelSize: 56
                    font.bold: true
                    topPadding: -10
                    bottomPadding: 10
                }
                MText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "ddd d MMM")
                }
                MText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "yyyy")
                    muted: true
                    sizeDelta: -1
                }
            }
        }

        Box {
            Layout.fillWidth: true
            implicitWidth: cal.implicitWidth + Theme.padL * 2
            implicitHeight: cal.implicitHeight + Theme.padL * 2
            Calendar {
                id: cal
                anchors.centerIn: parent
                cellSize: 34
            }
        }

        Box {
            Layout.preferredWidth: 210
            visible: root.player !== null
            ColumnLayout {
                anchors { fill: parent; margins: Theme.padL }
                spacing: Theme.gap

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 92
                    implicitHeight: 92
                    radius: Theme.radiusM
                    color: Theme.surfaceContainerHighest
                    clip: true
                    Image {
                        id: art
                        anchors.fill: parent
                        source: Player.path
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready
                    }
                    MIcon {
                        anchors.centerIn: parent
                        visible: art.status !== Image.Ready
                        text: "music_note"
                        size: 34
                        color: Theme.surfaceVariantText
                    }
                }
                MText {
                    Layout.fillWidth: true
                    text: root.player?.trackTitle ?? ""
                    font.bold: true
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }
                MText {
                    Layout.fillWidth: true
                    text: root.player?.trackArtist ?? ""
                    muted: true
                    sizeDelta: -1
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                }
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Theme.gap
                    MIconButton {
                        icon: "skip_previous"
                        size: 22
                        enabled: root.player?.canGoPrevious ?? false
                        opacity: enabled ? 1 : 0.4
                        onClicked: Player.previousOrRewind()
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
                        MIcon { text: "open_in_new"; size: 16; color: Theme.primary }
                        MText { text: root.player?.identity ?? "Open"; color: Theme.primary; sizeDelta: -1; elide: Text.ElideRight }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.player?.raise();
                            root.close();
                        }
                    }
                }
            }
        }
    }
}
