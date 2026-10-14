import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.theme

Card {
    implicitWidth: 300
    implicitHeight: 196

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 10

        StatHeader {
            icon: "memory-symbolic"
            title: "Memory"
            accent: Theme.tertiary
        }

        RowLayout {
            Layout.fillHeight: true
            spacing: 16

            CircularProgress {
                implicitWidth: 92
                implicitHeight: 92
                thickness: 8
                value: SysStats.memUsage
                fillColor: Theme.tertiary
                StyledText {
                    anchors.centerIn: parent
                    text: `${Math.round(SysStats.memUsage * 100)}%`
                    font.pixelSize: 20
                    font.bold: true
                    color: Theme.tertiary
                }
            }
            ColumnLayout {
                spacing: 2
                StyledText {
                    text: `${SysStats.formatBytes(SysStats.memUsed)} / ${SysStats.formatBytes(SysStats.memTotal)}`
                    font.bold: true
                }
                StyledText {
                    text: "Used"
                    font.pixelSize: 12
                    color: Theme.fgSurfaceVariant
                }
                StyledText {
                    Layout.topMargin: 8
                    visible: SysStats.swapTotal > 0
                    text: `Swap ${SysStats.formatBytes(SysStats.swapUsed)} / ${SysStats.formatBytes(SysStats.swapTotal)}`
                    font.pixelSize: 12
                    color: Theme.fgSurfaceVariant
                }
            }
        }
    }
}
