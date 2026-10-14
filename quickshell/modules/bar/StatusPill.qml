import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services
import qs.theme

// Status indicators + clock. Click toggles the control center on this screen.
Clickable {
    id: root

    required property string screenName
    readonly property bool active: Panels.controlCenterScreen === screenName

    implicitWidth: row.implicitWidth + 24
    implicitHeight: 32
    baseColor: active ? Theme.primary : Theme.surface
    onClicked: Panels.toggleControlCenter(screenName)

    readonly property color fg: active ? Theme.surface : Theme.fgSurface

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8

        Icon {
            id: recIcon
            visible: Recorder.active
            icon: "media-record-symbolic"
            color: root.active ? Theme.surface : Theme.error
            Blink {
                target: recIcon
                running: Recorder.active && !Recorder.paused
            }
        }
        Icon {
            visible: Net.showWifi
            icon: Net.wifiIcon
            color: root.fg
        }
        Icon {
            visible: Net.showWired
            icon: Net.wiredIcon
            color: root.fg
        }
        Icon {
            visible: Vpn.connected
            icon: "network-vpn-symbolic"
            color: root.fg
        }
        Icon {
            icon: Audio.speakerIcon
            color: root.fg
        }
        Icon {
            visible: Audio.micMuted
            icon: "microphone-sensitivity-muted-symbolic"
            color: Theme.error
        }
        Icon {
            visible: Config.notifications.dnd
            icon: "notification-disabled-symbolic"
            color: root.fg
        }
        StyledText {
            text: Time.monthDay
            color: root.fg
            font.pixelSize: 22
        }
        StyledText {
            text: Time.hhmm
            color: root.fg
            font.pixelSize: 22
        }
    }
}
