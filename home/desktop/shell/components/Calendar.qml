// Calendar — a self-contained month grid: Monday-first, today highlighted,
// chevrons page months, reset() returns to the current month. `today` follows a
// live clock (hour precision rolls it over at midnight).
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config

ColumnLayout {
    id: cal
    property int cellSize: 34

    SystemClock {
        id: clock
        precision: SystemClock.Hours
    }
    readonly property date today: clock.date
    property int year: new Date().getFullYear()
    property int month: new Date().getMonth()

    readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

    function daysInMonth(y, m) {
        return new Date(y, m + 1, 0).getDate();
    }
    function firstWeekday() {
        return (new Date(year, month, 1).getDay() + 6) % 7;
    }
    function step(delta) {
        let m = month + delta, y = year;
        if (m < 0) {
            m = 11;
            y--;
        } else if (m > 11) {
            m = 0;
            y++;
        }
        month = m;
        year = y;
    }
    function reset() {
        const n = new Date();
        year = n.getFullYear();
        month = n.getMonth();
    }

    spacing: Theme.gap

    RowLayout {
        Layout.fillWidth: true
        MIconButton { icon: "chevron_left"; size: 20; onClicked: cal.step(-1) }
        MText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: cal.monthNames[cal.month] + " " + cal.year
            font.bold: true
        }
        MIconButton { icon: "chevron_right"; size: 20; onClicked: cal.step(1) }
    }

    Grid {
        columns: 7
        spacing: 2

        Repeater {
            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
            delegate: Item {
                required property var modelData
                width: cal.cellSize
                height: cal.cellSize - 8
                MText { anchors.centerIn: parent; text: parent.modelData; muted: true; sizeDelta: -2 }
            }
        }

        Repeater {
            model: 42
            delegate: Item {
                required property int index
                readonly property int dayNum: index - cal.firstWeekday() + 1
                readonly property bool valid: dayNum >= 1 && dayNum <= cal.daysInMonth(cal.year, cal.month)
                readonly property bool isToday: valid && cal.year === cal.today.getFullYear() && cal.month === cal.today.getMonth() && dayNum === cal.today.getDate()
                width: cal.cellSize
                height: cal.cellSize - 6
                Rectangle {
                    anchors.centerIn: parent
                    width: cal.cellSize - 8
                    height: width
                    radius: width / 2
                    visible: parent.isToday || (dayMa.containsMouse && parent.valid)
                    color: parent.isToday ? Theme.primary : Theme.surfaceContainerHigh
                }
                MText {
                    anchors.centerIn: parent
                    visible: parent.valid
                    text: parent.dayNum
                    color: parent.isToday ? Theme.primaryText : Theme.surfaceText
                    font.bold: parent.isToday
                }
                MouseArea { id: dayMa; anchors.fill: parent; hoverEnabled: parent.valid }
            }
        }
    }
}
