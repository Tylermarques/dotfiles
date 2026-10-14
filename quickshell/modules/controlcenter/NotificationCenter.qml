import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.theme

// Notification history: count, "Clear all", scrollable list of cards.
Rectangle {
    id: root

    radius: 24
    color: Theme.surfaceContainerLow

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                implicitWidth: Math.max(32, count.implicitWidth + 16)
                implicitHeight: 32
                radius: 16
                color: Theme.tertiary
                StyledText {
                    id: count
                    anchors.centerIn: parent
                    text: Notifs.history.length
                    color: Theme.fgTertiary
                    font.pixelSize: 20
                }
            }
            StyledText {
                Layout.fillWidth: true
                text: "notifications"
                font.pixelSize: 17
            }
            Clickable {
                implicitWidth: clear.implicitWidth + 32
                implicitHeight: 30
                radius: 15
                onClicked: Notifs.clearAll()
                StyledText {
                    id: clear
                    anchors.centerIn: parent
                    text: "Clear all"
                }
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 12
            boundsBehavior: Flickable.StopAtBounds
            model: Notifs.history

            delegate: NotificationCard {
                required property var modelData
                width: ListView.view.width
                entry: modelData
                onCloseClicked: Notifs.dismissEntry(modelData)
            }

            StyledText {
                anchors.centerIn: parent
                visible: list.count === 0
                text: "No notifications"
                color: Theme.fgSurfaceVariant
            }
        }
    }
}
