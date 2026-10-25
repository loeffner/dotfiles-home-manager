// Quit — ends a dev scene after `delay` ms (scenes otherwise run until dev/run's
// timeout).
import QtQuick

Timer {
    property int delay: 3000
    interval: delay
    running: true
    onTriggered: Qt.exit(0)
}
