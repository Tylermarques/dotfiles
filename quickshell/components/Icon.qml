import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.theme

// Themed (Papirus) icon, recoloured like GTK symbolic icons.
IconImage {
    id: root

    property string icon
    property color color: Theme.fgSurface
    property int size: 18
    property bool recolor: true

    implicitSize: size
    source: icon.startsWith("/") ? `file://${icon}`
        : icon.startsWith("image:") || icon.startsWith("file:") ? icon
        : Quickshell.iconPath(icon, "image-missing")

    layer.enabled: recolor
    layer.effect: MultiEffect {
        brightness: 1.0
        colorization: 1.0
        colorizationColor: root.color
    }
}
