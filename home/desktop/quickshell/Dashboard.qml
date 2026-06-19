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

    anchors { top: true; left: true; right: true }
    // Position below the bar. The bar's exclusive zone handles this for Normal
    // surfaces, but we use Ignore (overlay), so set the margin explicitly.
    margins.top: Theme.barHeight
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // Fixed surface height — avoids resizing the Wayland surface every animation
    // frame (per-frame protocol messages stutter). The clip inside handles reveal.
    implicitHeight: cards.height + 16
    visible: false

    readonly property bool hasMedia: (Mpris.players?.values?.length ?? 0) > 0

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
                // Fill remaining width: total minus clock, media (if visible),
                // and spacing items.
                width: parent.width - 150 - (dash.hasMedia ? 220 : 0)
                       - (dash.hasMedia ? parent.spacing * 2 : parent.spacing)
                height: parent.height
                color: Theme.bgPopup
                radius: Theme.radius + 4
                border { width: 1; color: Theme.border }

                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutQuart } }

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

                readonly property var player: {
                    const ps = Mpris.players?.values ?? [];
                    return ps.find(p => p.playbackState === MprisPlaybackState.Playing) ?? ps[0] ?? null;
                }

                Column {
                    anchors { fill: parent; margins: Theme.pad }
                    spacing: Theme.gap

                    Item { height: 4 }

                    // Cover art
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 90; height: 90
                        radius: Theme.radius; color: Theme.bg1; clip: true

                        Image {
                            anchors.fill: parent
                            source: mediaCard.player?.trackArtUrl ?? ""
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: !(mediaCard.player?.trackArtUrl)
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
