import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services
import qs.theme

// Avatar with OS badge, user@host, compositor and uptime.
Card {
    id: root

    property string host: ""

    implicitHeight: 124

    FileView {
        path: "/etc/hostname"
        onLoaded: root.host = text().trim()
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 18

        Item {
            implicitWidth: 88
            implicitHeight: 88

            ClippingRectangle {
                anchors.fill: parent
                radius: width / 2
                color: Theme.surfaceContainerHighest

                Image {
                    anchors.fill: parent
                    source: Config.user.avatar ? `file://${Config.expand(Config.user.avatar)}` : ""
                    sourceSize.width: 176
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: -4
                width: 34
                height: 34
                radius: 17
                color: Theme.primaryContainer
                border.width: 3
                border.color: Theme.surfaceContainer
                // Full-colour logo (there is no symbolic one), so not recoloured.
                Icon {
                    anchors.centerIn: parent
                    icon: "distributor-logo-archlinux"
                    size: 20
                    recolor: false
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            StyledText {
                Layout.fillWidth: true
                text: `${Quickshell.env("USER")}<font color="${Theme.fgSurfaceVariant}">@${root.host}</font>`
                textFormat: Text.StyledText
                font.pixelSize: 22
                font.bold: true
                elide: Text.ElideRight
            }

            RowLayout {
                spacing: 8

                Rectangle {
                    implicitWidth: wm.implicitWidth + 24
                    implicitHeight: 28
                    radius: 14
                    color: Theme.secondaryContainer
                    Row {
                        id: wm
                        anchors.centerIn: parent
                        spacing: 6
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "preferences-system-windows-symbolic"
                            size: 14
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Hyprland"
                            font.pixelSize: 13
                        }
                    }
                }
                Rectangle {
                    implicitWidth: up.implicitWidth + 24
                    implicitHeight: 28
                    radius: 14
                    color: Theme.alpha(Theme.tertiary, 0.18)
                    Row {
                        id: up
                        anchors.centerIn: parent
                        spacing: 6
                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            icon: "alarm-symbolic"
                            size: 14
                            color: Theme.tertiary
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: SysStats.uptime > 0 ? `up ${SysStats.formatUptime(SysStats.uptime)}` : "up …"
                            font.pixelSize: 13
                            color: Theme.tertiary
                        }
                    }
                }
            }
        }
    }
}
