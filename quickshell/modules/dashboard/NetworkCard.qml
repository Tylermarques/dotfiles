import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.theme

// Throughput across wired/wireless interfaces; totals since the dashboard opened.
Card {
    id: root

    readonly property real peak: Math.max(...SysStats.netDownHistory, ...SysStats.netUpHistory, 1024)

    implicitWidth: 300
    implicitHeight: 196

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 8

        StatHeader {
            icon: "network-transmit-receive-symbolic"
            title: "Network"
            subtitle: `${SysStats.formatBytes(SysStats.netDownTotal)} down · ${SysStats.formatBytes(SysStats.netUpTotal)} up`
            accent: Theme.primary
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Sparkline {
                anchors.fill: parent
                values: SysStats.netDownHistory
                capacity: SysStats.historyLength
                max: root.peak
                lineColor: Theme.primary
            }
            Sparkline {
                anchors.fill: parent
                values: SysStats.netUpHistory
                capacity: SysStats.historyLength
                max: root.peak
                lineColor: Theme.tertiary
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Repeater {
                model: [
                    { icon: "go-down-symbolic", label: "Down", value: SysStats.netDown, color: Theme.primary },
                    { icon: "go-up-symbolic", label: "Up", value: SysStats.netUp, color: Theme.tertiary }
                ]
                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 6
                    Icon {
                        icon: parent.modelData.icon
                        size: 14
                        color: parent.modelData.color
                    }
                    StyledText {
                        text: `${SysStats.formatBytes(parent.modelData.value)}/s`
                        font.pixelSize: 13
                        font.bold: true
                        color: parent.modelData.color
                    }
                }
            }
        }
    }
}
