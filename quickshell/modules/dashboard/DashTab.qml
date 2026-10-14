import QtQuick
import QtQuick.Layouts
import qs.components

// Overview: user and uptime, clock, calendar, resource rings, now playing.
RowLayout {
    spacing: 12

    ColumnLayout {
        Layout.fillHeight: true
        spacing: 12

        UserCard {
            Layout.fillWidth: true
        }

        RowLayout {
            spacing: 12

            Card {
                Layout.fillHeight: true
                implicitWidth: 108
                ClockStack {
                    anchors.centerIn: parent
                }
            }
            Card {
                implicitWidth: calendar.implicitWidth + 32
                implicitHeight: calendar.implicitHeight + 32
                MonthCalendar {
                    id: calendar
                    anchors.centerIn: parent
                }
            }
            Card {
                Layout.fillHeight: true
                implicitWidth: resources.implicitWidth + 32
                ResourceRings {
                    id: resources
                    anchors.centerIn: parent
                }
            }
        }
    }

    Card {
        Layout.fillHeight: true
        implicitWidth: 240
        MiniMedia {
            anchors.fill: parent
            anchors.margins: 16
        }
    }
}
