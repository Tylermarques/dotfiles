import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.theme

// CPU/GPU: usage, temperature and a usage graph of the last minute.
Card {
    id: root

    property string icon
    property string title
    property string subtitle
    property real usage: 0
    property real temperature: NaN
    property var history: []
    property string extra: ""
    property color accent: Theme.primary

    implicitWidth: 468
    implicitHeight: 196

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 10

        RowLayout {
            Layout.fillWidth: true

            StatHeader {
                Layout.fillWidth: true
                icon: root.icon
                title: root.title
                subtitle: root.subtitle
                accent: root.accent
            }
            Rectangle {
                visible: !isNaN(root.temperature)
                implicitWidth: temp.implicitWidth + 20
                implicitHeight: 28
                radius: 14
                color: root.temperature > 85 ? Theme.alpha(Theme.error, 0.2) : Theme.alpha(Theme.fgSurface, 0.06)
                Row {
                    id: temp
                    anchors.centerIn: parent
                    spacing: 4
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "sensors-temperature-symbolic"
                        size: 14
                        color: root.temperature > 85 ? Theme.error : Theme.fgSurfaceVariant
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: `${Math.round(root.temperature)}°C`
                        font.pixelSize: 13
                        color: root.temperature > 85 ? Theme.error : Theme.fgSurface
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

            ColumnLayout {
                spacing: 0
                StyledText {
                    text: `${Math.round(root.usage * 100)}%`
                    font.pixelSize: 40
                    font.bold: true
                    color: root.accent
                }
                StyledText {
                    text: "Usage"
                    font.pixelSize: 12
                    color: Theme.fgSurfaceVariant
                }
                StyledText {
                    visible: root.extra !== ""
                    Layout.topMargin: 4
                    text: root.extra
                    font.pixelSize: 12
                    color: Theme.fgSurfaceVariant
                }
            }
            Sparkline {
                Layout.fillWidth: true
                Layout.fillHeight: true
                values: root.history
                capacity: SysStats.historyLength
                lineColor: root.accent
            }
        }
    }
}
