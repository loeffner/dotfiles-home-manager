// Self-contained month calendar. Monday-first grid, today highlighted,
// chevron buttons to page months. cellSize lets embedders make it more compact.
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: cal
    spacing: Theme.gap
    property int cellSize: 34 // reduce for compact embeddings

    readonly property date today: new Date()
    property int year: today.getFullYear()
    property int month: today.getMonth()

    readonly property var monthNames: ["January","February","March","April","May","June","July","August","September","October","November","December"]

    function daysInMonth(y, m) { return new Date(y, m + 1, 0).getDate(); }
    function firstWeekday() { return (new Date(year, month, 1).getDay() + 6) % 7; }
    function step(delta) {
        let m = month + delta, y = year;
        if (m < 0) { m = 11; y--; } else if (m > 11) { m = 0; y++; }
        month = m; year = y;
    }

    RowLayout {
        Layout.fillWidth: true
        MIconButton { icon: "chevron_left"; size: 20; onClicked: cal.step(-1) }
        Text {
            Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
            text: cal.monthNames[cal.month] + " " + cal.year
            color: Theme.surfaceText; font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: true
        }
        MIconButton { icon: "chevron_right"; size: 20; onClicked: cal.step(1) }
    }

    Grid {
        columns: 7
        spacing: 2

        Repeater {
            model: ["Mo","Tu","We","Th","Fr","Sa","Su"]
            delegate: Item {
                required property var modelData
                width: cal.cellSize; height: cal.cellSize - 8
                Text { anchors.centerIn: parent; text: parent.modelData; color: Theme.surfaceVariantText; font.family: Theme.font; font.pixelSize: Theme.fontSize - 2 }
            }
        }

        Repeater {
            model: 42
            delegate: Item {
                required property int index
                readonly property int dayNum: index - cal.firstWeekday() + 1
                readonly property bool valid: dayNum >= 1 && dayNum <= cal.daysInMonth(cal.year, cal.month)
                readonly property bool isToday: valid && cal.year === cal.today.getFullYear() && cal.month === cal.today.getMonth() && dayNum === cal.today.getDate()
                width: cal.cellSize; height: cal.cellSize - 6
                Rectangle {
                    anchors.centerIn: parent
                    width: cal.cellSize - 8; height: cal.cellSize - 8; radius: (cal.cellSize - 8) / 2
                    visible: parent.isToday || (dayMa.containsMouse && parent.valid)
                    color: parent.isToday ? Theme.primary : Theme.surfaceContainerHigh
                }
                Text {
                    anchors.centerIn: parent; visible: parent.valid; text: parent.dayNum
                    color: parent.isToday ? Theme.primaryText : Theme.surfaceText
                    font.family: Theme.font; font.pixelSize: Theme.fontSize; font.bold: parent.isToday
                }
                MouseArea { id: dayMa; anchors.fill: parent; hoverEnabled: parent.valid }
            }
        }
    }
}
