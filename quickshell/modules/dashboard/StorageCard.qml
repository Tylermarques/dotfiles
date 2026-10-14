import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.theme

// One bar per real filesystem (btrfs subvolumes of the same disk are merged).
Card {
    implicitWidth: 300
    implicitHeight: 196

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 10

        StatHeader {
            icon: "drive-harddisk-symbolic"
            title: "Storage"
            subtitle: SysStats.rootDisk ? `Root drive ${Math.round(SysStats.diskUsage * 100)}% full` : "No disks detected"
            accent: Theme.secondary
        }

        Repeater {
            model: SysStats.disks.slice(0, 3)

            ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        Layout.fillWidth: true
                        text: parent.parent.modelData.mount
                        font.pixelSize: 13
                        font.bold: true
                        elide: Text.ElideMiddle
                    }
                    StyledText {
                        text: `${SysStats.formatBytes(parent.parent.modelData.used)} / ${SysStats.formatBytes(parent.parent.modelData.total)}`
                        font.pixelSize: 12
                        color: Theme.fgSurfaceVariant
                    }
                }
                Slider {
                    Layout.fillWidth: true
                    implicitHeight: 8
                    trackHeight: 8
                    enabled: false
                    opacity: 1
                    fillColor: Theme.secondary
                    value: parent.modelData.total > 0 ? parent.modelData.used / parent.modelData.total : 0
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
