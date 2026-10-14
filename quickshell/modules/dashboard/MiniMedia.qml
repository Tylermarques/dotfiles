import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.theme

// Now playing: round cover inside a progress arc, track text, controls.
ColumnLayout {
    id: root

    readonly property var player: Media.active

    spacing: 6

    // MPRIS doesn't push position updates; poll while visible and playing.
    Timer {
        interval: 1000
        repeat: true
        running: root.visible && (root.player?.isPlaying ?? false)
        onTriggered: root.player.positionChanged()
    }

    Item {
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: 172
        implicitHeight: 172

        CircularProgress {
            anchors.fill: parent
            thickness: 5
            sweep: 300
            value: root.player && root.player.length > 0 ? root.player.position / root.player.length : 0
        }
        CoverArt {
            anchors.centerIn: parent
            width: 140
            height: 140
            radius: 70
            player: root.player
        }
    }

    StyledText {
        Layout.fillWidth: true
        Layout.topMargin: 4
        horizontalAlignment: Text.AlignHCenter
        text: root.player ? root.player.trackTitle || "Unknown title" : "No media"
        font.bold: true
        color: Theme.primary
        elide: Text.ElideRight
    }
    StyledText {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        visible: text !== ""
        text: root.player?.trackAlbum ?? ""
        font.pixelSize: 13
        color: Theme.outline
        elide: Text.ElideRight
    }
    StyledText {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        visible: text !== ""
        text: root.player?.trackArtist ?? ""
        font.pixelSize: 13
        color: Theme.secondary
        elide: Text.ElideRight
    }

    Item {
        Layout.fillHeight: true
    }

    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 8

        PlayerButton {
            icon: "media-skip-backward-symbolic"
            enabled: root.player?.canGoPrevious ?? false
            onClicked: root.player.previous()
        }
        PlayerButton {
            icon: root.player?.isPlaying ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
            filled: true
            checked: root.player?.isPlaying ?? false
            size: 48
            implicitWidth: 72
            enabled: root.player?.canTogglePlaying ?? false
            onClicked: root.player.togglePlaying()
        }
        PlayerButton {
            icon: "media-skip-forward-symbolic"
            enabled: root.player?.canGoNext ?? false
            onClicked: root.player.next()
        }
    }
}
