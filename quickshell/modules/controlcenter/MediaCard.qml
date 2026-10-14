import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.components
import qs.theme

// One MPRIS player: album art background tinted by its own dominant colour,
// title/artist, play/pause, seek bar, previous/next.
ClippingRectangle {
    id: root

    required property MprisPlayer player

    // Dark tint and light accent derived from the art (Ignis made a Material
    // scheme per cover; a hue-matched pair gets close without the cost).
    readonly property color artColor: quantizer.colors[0] ?? Theme.primary
    readonly property color tint: Qt.hsla(artColor.hslHue, Math.min(artColor.hslSaturation, 0.5), 0.12, 1)
    readonly property color accent: Qt.hsla(artColor.hslHue, Math.max(artColor.hslSaturation, 0.45), 0.78, 1)
    readonly property string art: player.trackArtUrl || Qt.resolvedUrl("../../assets/media-art-fallback.png")
    // ColorQuantizer only reads local files, so remote art is cached first.
    readonly property bool remoteArt: /^https?:/.test(art)
    readonly property string cachedArt: remoteArt ? `${Quickshell.cacheDir}/art/${Qt.md5(art)}` : ""
    property string quantizeSource: remoteArt ? "" : art

    // Same choices as Ignis (bundled symbolic icons for the common players).
    function playerIcon(): string {
        const id = `${player.desktopEntry} ${player.identity}`.toLowerCase();
        const name = id.includes("spotify") ? "spotify" : id.includes("firefox") ? "firefox-browser"
            : id.includes("chrom") ? "chrome" : "";
        return name ? `file://${Quickshell.shellDir}/assets/icons/${name}-symbolic.svg` : "folder-music-symbolic";
    }

    Layout.fillWidth: true
    implicitHeight: 176
    radius: 24
    color: tint

    onCachedArtChanged: if (remoteArt) fetchArt.running = true
    Component.onCompleted: if (remoteArt) fetchArt.running = true

    Process {
        id: fetchArt
        command: ["sh", "-c", 'test -s "$2" || { mkdir -p "$(dirname "$2")" && curl -sfLo "$2" "$1"; }', "sh", root.art, root.cachedArt]
        onExited: code => { if (code === 0) root.quantizeSource = `file://${root.cachedArt}`; }
    }

    ColorQuantizer {
        id: quantizer
        source: root.quantizeSource
        depth: 0
        rescaleSize: 64
    }

    Image {
        anchors.fill: parent
        source: root.art
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: 448
        asynchronous: true
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: Theme.alpha(root.tint, 0.9) }
            GradientStop { position: 0.5; color: Theme.alpha(root.tint, 0.4) }
            GradientStop { position: 1; color: Theme.alpha(root.tint, 0.9) }
        }
    }

    Icon {
        x: 16
        y: 18
        icon: root.playerIcon()
        size: 22
        color: root.accent
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: 16
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            StyledText {
                Layout.fillWidth: true
                text: root.player.trackTitle || root.player.identity
                font.bold: true
                color: "#f5f5f5"
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                text: root.player.trackArtist
                color: "#d0d0d0"
                elide: Text.ElideRight
            }
        }

        Clickable {
            visible: root.player.canPlay
            implicitWidth: 44
            implicitHeight: 44
            radius: root.player.isPlaying ? 16 : 22
            baseColor: root.accent
            onClicked: root.player.togglePlaying()
            Behavior on radius { NumberAnimation { duration: 200 } }
            Icon {
                anchors.centerIn: parent
                icon: root.player.isPlaying ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
                size: 18
                color: root.tint
            }
        }
    }

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 16
        spacing: 16

        Slider {
            id: seek
            Layout.fillWidth: true
            visible: root.player.positionSupported && root.player.length > 0
            enabled: root.player.canSeek
            trackHeight: 4
            trackColor: Theme.alpha("#f5f5f5", 0.2)
            fillColor: "#f5f5f5"
            value: root.player.length > 0 ? root.player.position / root.player.length : 0
            onMoved: v => root.player.position = v * root.player.length
        }
        Item {
            visible: !seek.visible
            Layout.fillWidth: true
        }
        Repeater {
            model: [
                { icon: "media-skip-backward-symbolic", can: root.player.canGoPrevious, run: () => root.player.previous() },
                { icon: "media-skip-forward-symbolic", can: root.player.canGoNext, run: () => root.player.next() }
            ]
            Clickable {
                required property var modelData
                visible: modelData.can
                implicitWidth: 28
                implicitHeight: 28
                radius: 14
                onClicked: modelData.run()
                Icon {
                    anchors.centerIn: parent
                    icon: parent.modelData.icon
                    size: 20
                    color: parent.hovered ? root.accent : "#f5f5f5"
                }
            }
        }
    }

    // MPRIS doesn't push position updates; poll only while visible and playing.
    Timer {
        interval: 1000
        repeat: true
        running: root.visible && root.player.isPlaying && root.player.positionSupported
        onTriggered: root.player.positionChanged()
    }
}
