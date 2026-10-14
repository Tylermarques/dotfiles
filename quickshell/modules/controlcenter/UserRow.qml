import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services
import qs.theme

// Avatar, user name + uptime, settings (opens config.json) and power buttons.
RowLayout {
    id: root

    property string uptime: ""

    signal closeRequested

    Layout.fillWidth: true
    spacing: 10

    function formatUptime(seconds: real): string {
        const pad = n => String(n).padStart(2, "0");
        const d = Math.floor(seconds / 86400), h = Math.floor(seconds % 86400 / 3600), m = Math.floor(seconds % 3600 / 60);
        return d ? `up ${pad(d)}:${pad(h)}:${pad(m)}` : `up ${pad(h)}:${pad(m)}`;
    }

    // /proc/uptime, re-read once a minute while the control center is open.
    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        onLoaded: root.uptime = root.formatUptime(parseFloat(text()))
    }
    Timer {
        interval: 60000
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: uptimeFile.reload()
    }

    ClippingRectangle {
        implicitWidth: 44
        implicitHeight: 44
        radius: 22
        color: Theme.surfaceContainerHigh

        Image {
            anchors.fill: parent
            source: Config.user.avatar ? `file://${Config.expand(Config.user.avatar)}` : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 88
            asynchronous: true
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        StyledText {
            text: Quickshell.env("USER")
            font.pixelSize: 18
        }
        StyledText {
            text: root.uptime
            color: Theme.fgSurfaceVariant
            font.pixelSize: 13
        }
    }

    Clickable {
        id: settings
        implicitWidth: 38
        implicitHeight: 38
        radius: 19
        baseColor: Theme.surfaceContainerHighest
        onClicked: {
            Quickshell.execDetached(["sh", "-c", `exec ${Config.apps.terminal} -e "\${EDITOR:-nvim}" "$1"`, "sh", Quickshell.shellDir + "/config.json"]);
            root.closeRequested();
        }
        Icon {
            anchors.centerIn: parent
            icon: "emblem-system-symbolic"
            size: 20
        }
        Tooltip {
            target: settings
            shown: settings.hovered
            text: "Edit config.json"
        }
    }
    Clickable {
        implicitWidth: 38
        implicitHeight: 38
        radius: 19
        baseColor: Theme.primary
        onClicked: {
            Panels.togglePowerMenu();
            root.closeRequested();
        }
        Icon {
            anchors.centerIn: parent
            icon: "system-shutdown-symbolic"
            size: 20
            color: Theme.surface
        }
    }
}
