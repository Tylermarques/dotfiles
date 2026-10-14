import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.theme

PanelWindow {
    id: bar

    required property ShellScreen modelData

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Config.bar.height
    color: "transparent"
    WlrLayershell.namespace: "quickshell:bar"
    WlrLayershell.layer: WlrLayer.Top

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.surface, 0.3)

        RowLayout {
            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
                leftMargin: 15
            }
            spacing: 8

            Workspaces {}
            MeetingButton {}
        }

        NowPlaying {
            anchors.centerIn: parent
        }

        RowLayout {
            anchors {
                right: parent.right
                verticalCenter: parent.verticalCenter
                rightMargin: 15
            }
            spacing: 8

            Tray {}
            KbLayout {}
            Battery {}
            StatusPill {
                screenName: bar.modelData.name
            }
        }
    }
}
