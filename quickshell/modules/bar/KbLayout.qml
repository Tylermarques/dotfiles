import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.components
import qs.theme

// First two letters of the main keyboard's active keymap; click = next layout.
Clickable {
    id: root

    property string keymap: ""

    visible: keymap !== ""
    implicitWidth: label.implicitWidth + 8
    implicitHeight: 32
    radius: 8
    onClicked: Quickshell.execDetached(["hyprctl", "switchxkblayout", "main", "next"])

    StyledText {
        id: label
        anchors.centerIn: parent
        text: root.keymap.slice(0, 2).toLowerCase()
        font.pixelSize: 20
    }

    Process {
        id: query
        running: true
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                const kb = JSON.parse(text).keyboards.find(k => k.main);
                if (kb) root.keymap = kb.active_keymap;
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent): void {
            // data: "<keyboard name>,<layout name>"
            if (event.name === "activelayout") query.running = true;
        }
    }
}
