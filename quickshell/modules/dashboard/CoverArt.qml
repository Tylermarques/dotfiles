import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.theme

// Rounded album art for a player, with the bundled fallback image.
ClippingRectangle {
    id: root

    property var player: null

    color: Theme.surfaceContainerHighest

    Image {
        anchors.fill: parent
        source: root.player?.trackArtUrl || Qt.resolvedUrl("../../assets/media-art-fallback.png")
        sourceSize.width: 512
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
}
