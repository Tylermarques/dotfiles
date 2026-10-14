import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets
import qs.components
import qs.services
import qs.theme

// Full player: big cover, track details, seek bar and controls, and a list of
// players to switch between. A blurred copy of the cover tints the background.
ClippingRectangle {
    id: root

    property MprisPlayer chosen: null
    readonly property MprisPlayer player: Media.players.includes(chosen) ? chosen : Media.active

    function time(seconds: real): string {
        if (!(seconds >= 0))
            return "--:--";
        const s = Math.floor(seconds);
        const h = Math.floor(s / 3600);
        const mm = String(Math.floor(s % 3600 / 60)).padStart(h ? 2 : 1, "0");
        return `${h ? h + ":" : ""}${mm}:${String(s % 60).padStart(2, "0")}`;
    }

    implicitWidth: 960
    implicitHeight: 340
    radius: 20
    color: Theme.surfaceContainer

    Timer {
        interval: 1000
        repeat: true
        running: root.visible && (root.player?.isPlaying ?? false)
        onTriggered: root.player.positionChanged()
    }

    Image {
        id: backdrop
        anchors.fill: parent
        visible: false
        source: root.player?.trackArtUrl ?? ""
        sourceSize.width: 256
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
    MultiEffect {
        anchors.fill: parent
        source: backdrop
        visible: root.player !== null && backdrop.status === Image.Ready
        blurEnabled: true
        blur: 1
        blurMax: 64
        opacity: 0.18
    }

    // Nothing playing
    ColumnLayout {
        anchors.centerIn: parent
        visible: root.player === null
        spacing: 8

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: 88
            implicitHeight: 88
            radius: 30
            color: Theme.primaryContainer
            Icon {
                anchors.centerIn: parent
                icon: "audio-x-generic-symbolic"
                size: 40
                color: Theme.fgPrimaryContainer
            }
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: "Nothing playing"
            font.pixelSize: 24
            font.bold: true
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: "Play something for it to show up here!"
            color: Theme.fgSurfaceVariant
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 28
        visible: root.player !== null

        CoverArt {
            Layout.preferredWidth: 292
            Layout.preferredHeight: 292
            radius: 28
            player: root.player
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 4

            StyledText {
                Layout.fillWidth: true
                text: root.player?.trackTitle || "Unknown title"
                font.pixelSize: 28
                font.bold: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                text: root.player?.trackArtist || "Unknown artist"
                font.pixelSize: 18
                color: Theme.secondary
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.player?.trackAlbum ?? ""
                color: Theme.outline
                elide: Text.ElideRight
            }

            Item {
                Layout.fillHeight: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                visible: root.player?.positionSupported ?? false

                StyledText {
                    text: root.time(root.player?.position ?? -1)
                    font.pixelSize: 13
                    color: Theme.fgSurfaceVariant
                }
                Slider {
                    Layout.fillWidth: true
                    enabled: root.player?.canSeek ?? false
                    trackHeight: 6
                    value: root.player && root.player.length > 0 ? root.player.position / root.player.length : 0
                    onMoved: v => root.player.position = v * root.player.length
                }
                StyledText {
                    text: root.player && root.player.length > 0 ? root.time(root.player.length) : "--:--"
                    font.pixelSize: 13
                    color: Theme.fgSurfaceVariant
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
                spacing: 10

                PlayerButton {
                    icon: "media-playlist-shuffle-symbolic"
                    visible: root.player?.shuffleSupported ?? false
                    checked: root.player?.shuffle ?? false
                    onClicked: root.player.shuffle = !root.player.shuffle
                }
                PlayerButton {
                    icon: "media-skip-backward-symbolic"
                    size: 48
                    enabled: root.player?.canGoPrevious ?? false
                    onClicked: root.player.previous()
                }
                PlayerButton {
                    icon: root.player?.isPlaying ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
                    filled: true
                    checked: root.player?.isPlaying ?? false
                    size: 60
                    implicitWidth: 96
                    enabled: root.player?.canTogglePlaying ?? false
                    onClicked: root.player.togglePlaying()
                }
                PlayerButton {
                    icon: "media-skip-forward-symbolic"
                    size: 48
                    enabled: root.player?.canGoNext ?? false
                    onClicked: root.player.next()
                }
                PlayerButton {
                    icon: root.player?.loopState === MprisLoopState.Track ? "media-playlist-repeat-song-symbolic" : "media-playlist-repeat-symbolic"
                    visible: root.player?.loopSupported ?? false
                    checked: (root.player?.loopState ?? MprisLoopState.None) !== MprisLoopState.None
                    onClicked: root.player.loopState = root.player.loopState === MprisLoopState.None ? MprisLoopState.Playlist
                        : root.player.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
                }
            }
        }

        // Player picker
        ColumnLayout {
            Layout.preferredWidth: 210
            Layout.fillHeight: true
            spacing: 6

            StyledText {
                text: "Players"
                font.bold: true
                color: Theme.fgSurfaceVariant
            }

            Repeater {
                model: Media.players

                Clickable {
                    id: entry
                    required property MprisPlayer modelData
                    readonly property bool current: modelData === root.player

                    Layout.fillWidth: true
                    implicitHeight: 52
                    radius: 14
                    baseColor: current ? Theme.secondaryContainer : Theme.alpha(Theme.fgSurface, 0.04)
                    onClicked: root.chosen = modelData

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        Icon {
                            icon: entry.modelData.isPlaying ? "media-playback-start-symbolic" : "media-playback-pause-symbolic"
                            size: 14
                            color: entry.current ? Theme.fgSecondaryContainer : Theme.fgSurfaceVariant
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            StyledText {
                                Layout.fillWidth: true
                                text: entry.modelData.identity
                                font.pixelSize: 13
                                font.bold: true
                                color: entry.current ? Theme.fgSecondaryContainer : Theme.fgSurface
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: entry.modelData.trackTitle
                                font.pixelSize: 12
                                color: Theme.fgSurfaceVariant
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }
    }
}
