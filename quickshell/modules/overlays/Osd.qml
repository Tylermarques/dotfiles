import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.services
import qs.theme

// Volume OSD at the bottom of the focused screen (`qs ipc call osd show`).
PanelWindow {
    id: root

    anchors.bottom: true
    margins.bottom: 80
    implicitWidth: box.implicitWidth
    implicitHeight: box.implicitHeight
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell:osd"
    WlrLayershell.layer: WlrLayer.Overlay
    mask: Region {}

    Rectangle {
        id: box
        implicitWidth: 288
        implicitHeight: row.implicitHeight + 32
        radius: 16
        color: Theme.surface
        border.width: 1
        border.color: Theme.alpha(Theme.outline, 0.2)

        RowLayout {
            id: row
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8

            Icon {
                icon: Audio.speakerIcon
                size: 26
            }
            Slider {
                Layout.fillWidth: true
                enabled: false
                opacity: 1
                value: Audio.muted ? 0 : Audio.volume
            }
        }
    }
}
