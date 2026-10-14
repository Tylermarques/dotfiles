import QtQuick
import qs.components
import qs.config
import qs.services
import qs.theme

// Centre of the bar: "artist - title" of the active MPRIS player.
Rectangle {
    id: root

    visible: Media.active !== null
    implicitWidth: label.implicitWidth + 2 * 20
    implicitHeight: 32
    radius: Theme.radius
    color: Theme.surface

    FontMetrics {
        id: metrics
        font: label.font
    }

    StyledText {
        id: label
        anchors.centerIn: parent
        width: Math.min(implicitWidth, metrics.averageCharacterWidth * Config.bar.nowPlayingMaxChars)
        text: Media.label(Media.active)
        font.bold: true
        elide: Text.ElideRight
    }
}
