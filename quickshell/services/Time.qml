pragma Singleton

import QtQuick
import Quickshell

Singleton {
    readonly property string hhmm: Qt.formatDateTime(clock.date, "HH:mm")
    // "Oct 14", "May 4"
    readonly property string monthDay: Qt.formatDateTime(clock.date, "MMM d")

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
