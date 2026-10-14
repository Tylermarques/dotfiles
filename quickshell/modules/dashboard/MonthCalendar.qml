import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.theme

// Month grid with today highlighted. Arrows or the scroll wheel change month.
ColumnLayout {
    id: root

    property int offset: 0      // months from the current one
    readonly property date today: Time.now
    readonly property date month: new Date(today.getFullYear(), today.getMonth() + offset, 1)
    readonly property int firstDay: Qt.locale().firstDayOfWeek % 7     // 0 = Sunday
    readonly property var days: {
        const start = new Date(month);
        start.setDate(1 - (month.getDay() - firstDay + 7) % 7);
        const cells = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(start);
            d.setDate(start.getDate() + i);
            cells.push(d);
        }
        return cells;
    }

    spacing: 6

    WheelHandler {
        onWheel: e => root.offset += e.angleDelta.y > 0 ? -1 : 1
    }

    RowLayout {
        Layout.fillWidth: true

        Clickable {
            implicitWidth: 28
            implicitHeight: 28
            radius: 14
            onClicked: root.offset--
            Icon {
                anchors.centerIn: parent
                icon: "go-previous-symbolic"
                size: 14
            }
        }
        Clickable {
            Layout.fillWidth: true
            implicitHeight: 28
            radius: 14
            onClicked: root.offset = 0
            StyledText {
                anchors.centerIn: parent
                text: Qt.formatDate(root.month, "MMMM yyyy")
                font.bold: true
                color: Theme.primary
            }
        }
        Clickable {
            implicitWidth: 28
            implicitHeight: 28
            radius: 14
            onClicked: root.offset++
            Icon {
                anchors.centerIn: parent
                icon: "go-next-symbolic"
                size: 14
            }
        }
    }

    GridLayout {
        columns: 7
        rowSpacing: 2
        columnSpacing: 2

        Repeater {
            model: 7
            StyledText {
                required property int index
                Layout.preferredWidth: 34
                horizontalAlignment: Text.AlignHCenter
                text: Qt.locale().dayName((root.firstDay + index) % 7, Locale.NarrowFormat)
                font.pixelSize: 12
                font.bold: true
                color: Theme.fgSurfaceVariant
            }
        }

        Repeater {
            model: root.days

            Rectangle {
                required property var modelData
                readonly property bool isToday: modelData.toDateString() === root.today.toDateString()
                readonly property bool inMonth: modelData.getMonth() === root.month.getMonth()

                Layout.preferredWidth: 34
                Layout.preferredHeight: 28
                radius: 14
                color: isToday ? Theme.primary : "transparent"

                StyledText {
                    anchors.centerIn: parent
                    text: parent.modelData.getDate()
                    font.pixelSize: 13
                    font.bold: parent.isToday
                    color: parent.isToday ? Theme.fgPrimary : Theme.fgSurface
                    opacity: parent.inMonth ? 1 : 0.35
                }
            }
        }
    }
}
