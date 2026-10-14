import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
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

        // Hovering the centre opens the dashboard (after a short delay, so
        // passing through doesn't); clicking pins it open or closes it.
        MouseArea {
            id: dashZone
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(nowPlaying.width + 48, 480)
            height: parent.height
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: {
                Panels.dashboardBarHovered = containsMouse;
                if (containsMouse)
                    openDelay.restart();
                else
                    openDelay.stop();
            }
            onClicked: {
                openDelay.stop();
                Panels.toggleDashboard(bar.modelData.name);
            }

            Timer {
                id: openDelay
                interval: 200
                onTriggered: Panels.openDashboard(bar.modelData.name, false)
            }
        }

        NowPlaying {
            id: nowPlaying
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
