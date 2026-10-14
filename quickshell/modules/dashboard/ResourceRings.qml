import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.theme

// CPU, memory and root-disk usage as rings, top to bottom.
ColumnLayout {
    spacing: 10

    Repeater {
        model: [
            { icon: "cpu-symbolic", value: SysStats.cpuUsage, color: Theme.primary, label: "CPU" },
            { icon: "memory-symbolic", value: SysStats.memUsage, color: Theme.tertiary, label: "Memory" },
            { icon: "drive-harddisk-symbolic", value: SysStats.diskUsage, color: Theme.secondary, label: "Disk" }
        ]

        CircularProgress {
            id: ring
            required property var modelData
            implicitWidth: 62
            implicitHeight: 62
            thickness: 6
            value: modelData.value
            fillColor: modelData.color

            Icon {
                anchors.centerIn: parent
                icon: ring.modelData.icon
                size: 20
                color: ring.modelData.color
                visible: !ringHover.hovered
            }
            StyledText {
                anchors.centerIn: parent
                visible: ringHover.hovered
                text: `${Math.round(ring.modelData.value * 100)}%`
                font.pixelSize: 13
                font.bold: true
                color: ring.modelData.color
            }
            HoverHandler {
                id: ringHover
            }
        }
    }
}
