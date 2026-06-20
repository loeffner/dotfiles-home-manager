// Now-playing widget (MPRIS). Hidden unless a player exists. The bar shows a
// state glyph + elided title; clicking opens a popup with cover art, metadata,
// previous / play-pause / next, and a jump-to-app button (raise()).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris

Item {
    id: root
    required property var bar

    readonly property var player: MediaThumb.active
    readonly property bool playing: player && player.playbackState === MprisPlaybackState.Playing

    visible: player !== null
    implicitWidth: row.implicitWidth
    implicitHeight: Theme.barHeight

    opacity: ma.containsMouse ? 1.0 : 0.82
    Behavior on opacity {
        NumberAnimation {
            duration: 70
        }
    }

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: Theme.gap

        Text {
            text: root.playing ? "󰏤" : "󰐊"
            font.family: Theme.font
            font.pixelSize: Theme.iconSize
            color: Theme.fg
        }
        Text {
            Layout.maximumWidth: 200
            elide: Text.ElideRight
            text: root.player ? (root.player.trackTitle ?? "") : ""
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            color: Theme.dim
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: popup.toggle()
    }

    BarPopup {
        id: popup
        bar: root.bar
        anchorItem: root
        popWidth: 320

        // Cover art + metadata.
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.pad

            Rectangle {
                implicitWidth: 56
                implicitHeight: 56
                radius: 8
                color: Theme.bg1
                clip: true

                Image {
                    id: popupArt
                    anchors.fill: parent
                    source: MediaThumb.path
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent
                    visible: popupArt.status !== Image.Ready
                    text: "󰎈"
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.iconSize
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: root.player ? (root.player.trackTitle || "Unknown") : ""
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: root.player ? [root.player.trackArtist, root.player.trackAlbum].filter(s => s).join("  ·  ") : ""
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    elide: Text.ElideRight
                }
            }
        }

        // Transport controls + jump-to-app.
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.pad

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: "󰒮"
                color: (root.player && root.player.canGoPrevious) ? Theme.fg : Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.iconSize + 4
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.player?.previous()
                }
            }
            Text {
                text: root.playing ? "󰏤" : "󰐊"
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.iconSize + 8
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.player?.togglePlaying()
                }
            }
            Text {
                text: "󰒭"
                color: (root.player && root.player.canGoNext) ? Theme.fg : Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.iconSize + 4
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.player?.next()
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: "󰗖" // jump to the playing app
                color: (root.player && root.player.canRaise) ? Theme.accent : Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.iconSize
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.player && root.player.canRaise) {
                            root.player.raise();
                            popup.hide();
                        }
                    }
                }
            }
        }
    }
}
