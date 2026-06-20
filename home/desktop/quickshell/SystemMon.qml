// System monitor: a single chip glyph in the bar; click opens a popup with CPU /
// RAM mini bar-graphs, network rates, and the top processes by CPU. Data comes
// from SystemStats (which polls faster while this popup is open).
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    required property var bar

    implicitWidth: glyph.implicitWidth
    implicitHeight: Theme.barHeight

    opacity: ma.containsMouse ? 1.0 : 0.82
    Behavior on opacity { NumberAnimation { duration: 70 } }

    Text {
        id: glyph
        anchors.centerIn: parent
        text: "󰻠" // cpu
        font.family: Theme.font
        font.pixelSize: Theme.iconSize
        color: SystemStats.cpu > 0.85 ? Theme.urgent : Theme.fg
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: popup.toggle()
    }

    // Faster polling + `ps` only while the popup is open.
    Binding {
        target: SystemStats
        property: "active"
        value: popup.isOpen
    }

    BarPopup {
        id: popup
        bar: root.bar
        anchorItem: root
        popWidth: 280

        // ── CPU / RAM bar-graphs ────────────────────────────────────────────
        component MetricRow: RowLayout {
            property string label: ""
            property real value: 0       // 0..1
            property string trailing: ""
            Layout.fillWidth: true
            spacing: Theme.gap

            Text {
                text: parent.label
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                Layout.preferredWidth: 32
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 6
                radius: 3
                color: Theme.bg1
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, parent.parent.value))
                    height: parent.height
                    radius: 3
                    color: parent.parent.value > 0.85 ? Theme.urgent : Theme.accent
                    Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                }
            }
            Text {
                text: parent.trailing
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                horizontalAlignment: Text.AlignRight
                Layout.minimumWidth: 64
            }
        }

        Text {
            text: "System"
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            font.bold: true
        }

        MetricRow {
            label: "CPU"
            value: SystemStats.cpu
            trailing: Math.round(SystemStats.cpu * 100) + "%"
        }
        MetricRow {
            label: "RAM"
            value: SystemStats.mem
            trailing: SystemStats.memUsedGB.toFixed(1) + "/" + SystemStats.memTotalGB.toFixed(1) + "G"
        }

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Net"
                color: Theme.dim
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
                Layout.preferredWidth: 32
            }
            Text {
                Layout.fillWidth: true
                text: "󰇚 " + SystemStats.fmtRate(SystemStats.netRx) + "    󰕒 " + SystemStats.fmtRate(SystemStats.netTx)
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.border
            opacity: 0.5
        }

        Text {
            text: "Top processes"
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
        }

        Repeater {
            model: SystemStats.procs
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: Theme.gap

                Text {
                    Layout.fillWidth: true
                    text: modelData.comm
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    elide: Text.ElideRight
                }
                Text {
                    text: modelData.cpu.toFixed(0) + "%"
                    color: modelData.cpu > 50 ? Theme.warn : Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    horizontalAlignment: Text.AlignRight
                    Layout.minimumWidth: 36
                }
            }
        }
    }
}
