// Camera-import progress OSD: a transient pill near the top edge, shown while
// `camera-import` pulls photos off the camera. Mirrors Osd.qml's look, but is
// driven over IPC (via the CameraImport singleton) instead of by Pipewire/MPRIS.
//
// It stays up for the whole import (no auto-hide while running); on finish it
// shows a brief done/error state, then fades. A determinate fill tracks
// files-pulled / total when the count is known; otherwise an indeterminate
// marquee sweeps while running.
import QtQuick
import QtQuick.Layouts
import Quickshell

PanelWindow {
    id: osd
    required property var modelData
    screen: modelData

    anchors.top: true
    margins.top: Theme.barHeight + 12
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    // Fixed surface — avoids per-frame Wayland resizes; content centres in it.
    implicitWidth: 320
    implicitHeight: 48
    visible: false

    readonly property string phase: CameraImport.phase
    readonly property bool indeterminate: CameraImport.indeterminate
    readonly property real fraction: CameraImport.fraction

    function showNow() {
        visible = true;
        fadeOut.stop();
        fadeIn.start();
    }
    function hide() {
        if (!visible)
            return;
        fadeIn.stop();
        fadeOut.start();
    }

    // After a finished/failed import, linger briefly then fade and reset to idle.
    Timer {
        id: hideTimer
        interval: 2600
        onTriggered: {
            osd.hide();
            CameraImport.phase = "idle";
        }
    }

    // Backstop: if a running import goes silent for this long (no progress and no
    // finish/fail), assume the script died or its terminal IPC was lost, and hide
    // rather than stranding the pill forever. Generous so a slow single-file copy
    // (e.g. a large video over SMB) can't trip it; real imports tick well inside it.
    Timer {
        id: watchdog
        interval: 300000 // 5 min
        onTriggered: {
            osd.hide();
            CameraImport.phase = "idle";
        }
    }

    Connections {
        target: CameraImport
        function onPhaseChanged() {
            switch (CameraImport.phase) {
            case "running":
                hideTimer.stop();
                watchdog.restart();
                osd.showNow();
                break;
            case "done":
            case "error":
                watchdog.stop();
                osd.showNow(); // already up; keep it up for the result beat
                hideTimer.restart();
                break;
            case "idle":
                watchdog.stop();
                osd.hide();
                break;
            }
        }
        // Each progress tick proves the import is alive — keep the watchdog at bay.
        function onDoneChanged() {
            if (CameraImport.phase === "running")
                watchdog.restart();
        }
    }

    Rectangle {
        id: pill
        anchors.fill: parent
        radius: Theme.radiusL
        color: Theme.surface
        border.width: 1
        border.color: Theme.outline
        opacity: 0

        // Accent while running, green on success, red on failure.
        readonly property color tint: osd.phase === "error" ? Theme.urgent : osd.phase === "done" ? Theme.good : Theme.primary

        NumberAnimation {
            id: fadeIn
            target: pill; property: "opacity"; to: 1
            duration: 120; easing.type: Easing.OutQuart
        }
        NumberAnimation {
            id: fadeOut
            target: pill; property: "opacity"; to: 0
            duration: 200; easing.type: Easing.InQuart
            onFinished: osd.visible = false
        }

        RowLayout {
            anchors { fill: parent; leftMargin: Theme.pad; rightMargin: Theme.pad }
            spacing: Theme.gap

            // Phase glyph: camera while pulling off the card, NAS/server while
            // copying to the share, check on success, alert on failure.
            Text {
                font.family: Theme.font
                font.pixelSize: Theme.iconSize + 3
                color: pill.tint
                Layout.preferredWidth: Theme.iconSize + 6
                horizontalAlignment: Text.AlignHCenter
                text: osd.phase === "error" ? "󰀦" : osd.phase === "done" ? "󰄬" : CameraImport.stage === "filing" ? "󰒋" : "󰄀"
            }

            // Progress track.
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 6
                radius: 3
                color: Theme.surfaceContainerHigh
                clip: true

                // Determinate fill — used when the total is known, or always at
                // 100% once done.
                Rectangle {
                    visible: !osd.indeterminate || osd.phase === "done"
                    width: parent.width * (osd.phase === "done" ? 1 : Math.min(1, osd.fraction))
                    height: parent.height
                    radius: 3
                    color: pill.tint
                    Behavior on width { NumberAnimation { duration: 120 } }
                }

                // Indeterminate marquee — only while running with an unknown total.
                Rectangle {
                    id: marquee
                    visible: osd.indeterminate && osd.phase === "running"
                    width: parent.width * 0.3
                    height: parent.height
                    radius: 3
                    color: pill.tint
                    SequentialAnimation on x {
                        running: marquee.visible
                        loops: Animation.Infinite
                        NumberAnimation {
                            from: -marquee.width; to: marquee.parent.width
                            duration: 950; easing.type: Easing.InOutQuad
                        }
                    }
                }
            }

            // N/M while running, the result text on done/error.
            Text {
                color: Theme.surfaceVariantText
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                Layout.minimumWidth: 54
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                text: {
                    if (osd.phase === "done" || osd.phase === "error")
                        return CameraImport.message;
                    if (osd.indeterminate)
                        return CameraImport.done > 0 ? CameraImport.done + "…" : "…";
                    return CameraImport.done + "/" + CameraImport.total;
                }
            }
        }
    }
}
