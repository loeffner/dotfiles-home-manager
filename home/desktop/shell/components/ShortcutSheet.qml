// ShortcutSheet — a popout's "?" overlay: its keyboard shortcuts in sections,
// keys drawn as keycaps, the section for the current view highlighted (the
// others dimmed). IslandPanel hosts one per panel; a click on it emits
// dismissed().
//
// sections: [{ title, keys: [[[cap, …], description], …], always? }] — an
// `always` section is never dimmed (the shared "Everywhere" one).
import QtQuick
import QtQuick.Layouts
import qs.config

Rectangle {
    id: root
    property var sections: []
    property int current: 0
    property bool shown: false
    // Height the sheet needs (the panel grows to it while the sheet is up).
    readonly property real contentHeight: column.implicitHeight + Theme.padL * 3
    signal dismissed

    color: Theme.popout
    // It covers the whole panel, so it follows the island's shape: square at the
    // top (flush with the bar), rounded at the bottom. The island's clip is
    // rectangular and wouldn't round it.
    bottomLeftRadius: Math.min(Theme.radiusL, height / 2, width / 2)
    bottomRightRadius: Math.min(Theme.radiusL, height / 2, width / 2)
    opacity: shown ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Theme.durShort } }

    // The island's starry backdrop, which the opaque sheet covers — the same
    // density and look, re-scattered each time the sheet comes up.
    StarField {
        id: stars
        anchors.fill: parent
        starCount: Math.max(24, Math.min(120, Math.round(width * height / 1400)))
        maxOpacity: 0.18
        maxRadius: 1.3
    }
    onShownChanged: if (shown)
        stars.seed = Math.floor(Math.random() * 2147483647)

    MouseArea {
        anchors.fill: parent
        onClicked: root.dismissed()
    }

    Column {
        id: column
        anchors.centerIn: parent
        width: Math.min(parent.width - Theme.padL * 2, 360)
        spacing: Theme.gapL + 4

        RowLayout {
            width: parent.width
            spacing: Theme.gap
            MIcon {
                text: "keyboard"
                size: 18
                color: Theme.primary
            }
            MText {
                Layout.fillWidth: true
                text: "Keyboard shortcuts"
                font.bold: true
            }
            MText {
                text: "any key closes"
                muted: true
                sizeDelta: -2
            }
        }

        Repeater {
            model: root.sections
            delegate: Column {
                id: section
                required property var modelData
                required property int index
                readonly property bool current: index === root.current || section.modelData.always === true
                width: parent.width
                spacing: 5

                MText {
                    visible: root.sections.length > 1
                    text: section.modelData.title.toUpperCase()
                    sizeDelta: -3
                    font.bold: true
                    font.letterSpacing: 0.8
                    color: section.current ? Theme.primary : Theme.surfaceVariantText
                    bottomPadding: 2
                }
                Repeater {
                    model: section.modelData.keys
                    delegate: RowLayout {
                        id: shortcut
                        required property var modelData
                        width: section.width
                        spacing: Theme.gap
                        opacity: section.current ? 1 : 0.6

                        Row {
                            Layout.preferredWidth: 112 // fits two caps like "Enter" + "Space"
                            spacing: 4
                            Repeater {
                                model: shortcut.modelData[0]
                                // A keycap.
                                delegate: Rectangle {
                                    required property string modelData
                                    implicitWidth: Math.max(24, cap.implicitWidth + 12)
                                    implicitHeight: 22
                                    radius: 5
                                    color: Theme.surfaceContainerHigh
                                    border.width: 1
                                    border.color: Theme.outline
                                    MText {
                                        id: cap
                                        anchors.centerIn: parent
                                        text: parent.modelData
                                        sizeDelta: -2
                                        font.bold: true
                                    }
                                }
                            }
                        }
                        MText {
                            Layout.fillWidth: true
                            text: shortcut.modelData[1]
                            sizeDelta: -1
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }
}
