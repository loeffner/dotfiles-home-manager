// PanelHeader — a popout's title row: optional accent icon, bold title filling
// the width, then any trailing actions (children are appended after the title).
import QtQuick
import QtQuick.Layouts
import qs.config

RowLayout {
    id: root
    property string icon: ""
    property string title: ""
    default property alias actions: trailing.data

    Layout.fillWidth: true
    spacing: Theme.gap

    MIcon {
        visible: root.icon !== ""
        text: root.icon
        size: 18
        color: Theme.primary
    }
    MText {
        text: root.title
        sizeDelta: 1
        font.bold: true
        Layout.fillWidth: true
    }
    RowLayout {
        id: trailing
        spacing: Theme.gap
    }
}
