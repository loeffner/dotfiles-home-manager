// Dashboard: three floating cards that slide down from the bar when the clock
// is clicked. Modelled on caelestia — separate card panels on a transparent
// background. Cards: stacked clock+date | month calendar | media (when active).
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris

PanelWindow {
    id: dash
    required property var modelData
    screen: modelData

    // Full-screen below the bar. Keeping everything in ONE window makes child
    // stacking deterministic: the backdrop MouseArea sits below the cards, so
    // card controls receive clicks and only empty space dismisses. (A separate
    // backdrop window had ambiguous cross-surface z-order and ate the clicks.)
    anchors { top: true; bottom: true; left: true; right: true }
    margins.top: Theme.barHeight
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: false

    readonly property bool hasMedia: MediaThumb.active !== null

    // Click anywhere outside the cards to dismiss.
    MouseArea {
        anchors.fill: parent
        onClicked: ShellState.dashboardOpen = false
    }

    // ── Open / close ───────────────────────────────────────────────────────
    function open() {
        visible = true;
        closeAnim.stop();
        Qt.callLater(() => { openAnim.to = cards.height + 16; openAnim.start(); });
    }
    function close() {
        if (!visible) return;
        openAnim.stop();
        closeAnim.start();
    }

    Connections {
        target: ShellState
        function onDashboardOpenChanged() {
            ShellState.dashboardOpen ? dash.open() : dash.close();
        }
    }

    // ── Animated clip ──────────────────────────────────────────────────────
    Item {
        id: clipper
        anchors { top: parent.top; left: parent.left; right: parent.right }
        clip: true
        height: 0
        layer.enabled: true // cache cards as GPU texture — no re-render each frame

        NumberAnimation {
            id: openAnim; target: clipper; property: "height"
            duration: 180; easing.type: Easing.OutQuart
        }
        NumberAnimation {
            id: closeAnim; target: clipper; property: "height"; to: 0
            duration: 100; easing.type: Easing.InQuart
            onFinished: dash.visible = false
        }

        // Cards row — centred horizontally, max 900 px wide.
        Row {
            id: cards
            anchors { top: parent.top; topMargin: 8; horizontalCenter: parent.horizontalCenter }
            width: Math.min(dash.width - 48, 900)
            height: 252
            spacing: 10

            // ── Card 1 : Clock + date ────────────────────────────────────
            Rectangle {
                width: 150; height: parent.height
                color: Theme.bgPopup
                radius: Theme.radius + 4
                border { width: 1; color: Theme.border }
                clip: true

                // Space — subtle starfield behind the clock hands.
                StarField {
                    anchors.fill: parent
                    starCount: 40
                    seed: 13
                    maxOpacity: 0.28
                }

                // Swallow clicks so clicking the card doesn't dismiss the dashboard.
                MouseArea { anchors.fill: parent }

                SystemClock { id: dashClock; precision: SystemClock.Minutes }

                Column {
                    anchors.centerIn: parent
                    spacing: 0

                    // Hour — large, tight spacing with dots below
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(dashClock.date, "HH")
                        color: Theme.accent
                        font { family: Theme.font; pixelSize: 58; bold: true }
                        // Pull toward the separator
                        bottomPadding: -10
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "•••"
                        color: Theme.dim
                        font { family: Theme.font; pixelSize: 16 }
                        topPadding: -10
                        bottomPadding: -10
                    }
                    // Minute
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(dashClock.date, "mm")
                        color: Theme.accent
                        font { family: Theme.font; pixelSize: 58; bold: true }
                        topPadding: -10
                        bottomPadding: 8
                    }

                    // Date below the clock
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(dashClock.date, "ddd d MMM")
                        color: Theme.fg
                        font { family: Theme.font; pixelSize: Theme.fontSize }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDateTime(dashClock.date, "yyyy")
                        color: Theme.dim
                        font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
                    }
                }
            }

            // ── Card 2 : Calendar ────────────────────────────────────────
            Rectangle {
                width: parent.width - 150 - (dash.hasMedia ? 220 : 0)
                       - (dash.hasMedia ? parent.spacing * 2 : parent.spacing)
                height: parent.height
                color: Theme.bgPopup
                radius: Theme.radius + 4
                border { width: 1; color: Theme.border }
                clip: true

                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutQuart } }

                StarField {
                    anchors.fill: parent
                    starCount: 55
                    seed: 99
                    maxOpacity: 0.20
                    maxRadius: 1.3
                }

                MouseArea { anchors.fill: parent }

                Calendar {
                    id: dashCal
                    cellSize: 30
                    anchors.centerIn: parent

                    Connections {
                        target: ShellState
                        function onDashboardOpenChanged() {
                            if (ShellState.dashboardOpen) {
                                const n = new Date();
                                dashCal.year = n.getFullYear();
                                dashCal.month = n.getMonth();
                            }
                        }
                    }
                }
            }

            // ── Card 3 : Media (fades in/out with player) ───────────────
            Rectangle {
                width: 220; height: parent.height
                color: Theme.bgPopup
                radius: Theme.radius + 4
                border { width: 1; color: Theme.border }
                clip: true
                visible: dash.hasMedia
                opacity: 0

                // Fade + slight upward slide on appear.
                readonly property bool showing: dash.hasMedia
                onShowingChanged: {
                    if (showing) { slideIn.restart(); }
                    else         { opacity = 0; }
                }
                SequentialAnimation {
                    id: slideIn
                    NumberAnimation { target: mediaCard; property: "y"; from: 8; to: 0; duration: 150; easing.type: Easing.OutQuart }
                    // opacity via parallel
                }
                NumberAnimation on opacity {
                    id: mediaFade
                    running: dash.hasMedia
                    from: 0; to: 1; duration: 160; easing.type: Easing.OutQuart
                }

                id: mediaCard

                StarField {
                    anchors.fill: parent
                    starCount: 35
                    seed: 77
                    maxOpacity: 0.22
                    maxRadius: 1.4
                }

                MouseArea { anchors.fill: parent }

                readonly property var player: MediaThumb.active

                Column {
                    anchors { fill: parent; margins: Theme.pad }
                    spacing: Theme.gap

                    Item { height: 4 }

                    // Cover art — sourced from MediaThumb (handles remote YouTube
                    // CDN URLs via curl, local file:// URLs directly).
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 90; height: 90
                        radius: Theme.radius; color: Theme.bg1; clip: true

                        Image {
                            id: dashArt
                            anchors.fill: parent
                            source: MediaThumb.path
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: dashArt.status !== Image.Ready
                            text: "󰎈"; color: Theme.dim
                            font { family: Theme.font; pixelSize: 32 }
                        }
                    }

                    Text {
                        width: parent.width
                        text: mediaCard.player?.trackTitle ?? ""
                        color: Theme.fg; font { family: Theme.font; pixelSize: Theme.fontSize; bold: true }
                        elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        width: parent.width
                        text: mediaCard.player?.trackArtist ?? ""
                        color: Theme.dim; font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
                        elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
                    }

                    // Transport controls
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.pad * 2

                        Text {
                            text: "󰒮"
                            color: mediaCard.player?.canGoPrevious ? Theme.fg : Theme.dim
                            font { family: Theme.font; pixelSize: Theme.iconSize + 2 }
                            MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: mediaCard.player?.previous() }
                        }
                        Text {
                            text: mediaCard.player?.playbackState === MprisPlaybackState.Playing ? "󰏤" : "󰐊"
                            color: Theme.fg
                            font { family: Theme.font; pixelSize: Theme.iconSize + 10 }
                            MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: mediaCard.player?.togglePlaying() }
                        }
                        Text {
                            text: "󰒭"
                            color: mediaCard.player?.canGoNext ? Theme.fg : Theme.dim
                            font { family: Theme.font; pixelSize: Theme.iconSize + 2 }
                            MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: mediaCard.player?.next() }
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: mediaCard.player?.canRaise ?? false
                        text: "󰗖  " + (mediaCard.player?.identity ?? "Open")
                        color: Theme.accent
                        font { family: Theme.font; pixelSize: Theme.fontSize - 1 }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { mediaCard.player?.raise(); ShellState.dashboardOpen = false; }
                        }
                    }
                }
            }
        }
    }
}
