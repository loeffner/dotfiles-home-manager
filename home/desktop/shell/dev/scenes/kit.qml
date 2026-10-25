// Scene: every component of the kit on one card, for a visual smoke test.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.dev

ShellRoot {
    PanelWindow {
        anchors { top: true; left: true }
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: 760
        implicitHeight: 420
        color: Theme.popout

        RowLayout {
            anchors { fill: parent; margins: Theme.padL }
            spacing: Theme.gapL
            ColumnLayout {
                Layout.preferredWidth: 380
                Layout.alignment: Qt.AlignTop
                spacing: Theme.gapL
                PanelHeader {
                    icon: "content_paste"
                    title: "Panel header"
                    MIconButton { icon: "delete"; raised: true }
                    MIconButton { icon: "settings" }
                }
                RowLayout {
                    MButton { label: "Filled"; filled: true }
                    MButton { label: "Tile"; icon: "search" }
                    MToggle { checked: true }
                    MToggle {}
                }
                MSlider { Layout.fillWidth: true; value: 0.42; icon: "volume_up" }
                MTextField { Layout.fillWidth: true; icon: "search"; placeholder: "Search" }
                MTextField { Layout.fillWidth: true; icon: "password"; placeholder: "Passphrase"; password: true; text: "secret" }
                Divider {}
                ListRow { Layout.fillWidth: true; implicitHeight: 30; MText { anchors.centerIn: parent; text: "List row (rest)" } }
                ListRow { Layout.fillWidth: true; implicitHeight: 30; selected: true; MText { anchors.centerIn: parent; text: "List row (selected)" } }
                RowLayout {
                    MText { text: "Body" }
                    MText { text: "muted -2"; muted: true; sizeDelta: -2 }
                    Chevron {}
                    Chevron { expanded: true }
                    MIcon { text: "wifi"; color: Theme.primary }
                }
            }
            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                RowLayout {
                    CircleGauge { diameter: 92; value: 0.37; value2: 0.55; big: "37%"; small: "55°C"; caption: "CPU" }
                    CircleGauge { diameter: 92; value: 0.81; big: "81%"; caption: "Memory" }
                }
                Calendar { cellSize: 34 }
            }
        }
        StarField { anchors.fill: parent; starCount: 80; maxOpacity: 0.18; maxRadius: 1.3; z: -1 }
    }
    Snap { name: "kit"; region: "0,0 760x420"; delay: 800 }
    Quit { delay: 1500 }
}
