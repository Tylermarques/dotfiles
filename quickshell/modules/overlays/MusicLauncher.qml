import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.services
import qs.theme

// Search the mpd library and play a song, artist, album or playlist.
// Tab / Shift+Tab switch mode, Up/Down pick a result, Enter plays, Esc closes.
PanelWindow {
    id: root

    readonly property var modes: ["All Songs", "Artists", "Albums", "Playlists"]
    property int mode: 0
    property int selected: 0

    readonly property string query: input.text.toLowerCase()
    readonly property var results: {
        if (!query)
            return [];
        const match = s => s.toLowerCase().includes(query);
        switch (mode) {
        case 0:
            return Mpd.songs.filter(p => match(p) || match(Mpd.trackLabel(p))).slice(0, 20)
                .map(p => ({ label: Mpd.trackLabel(p), value: p }));
        case 1:
            return Mpd.artists.filter(match).slice(0, 20).map(a => ({ label: a, value: a }));
        case 2:
            return Mpd.albums.filter(match).slice(0, 20).map(a => ({ label: a, value: a }));
        default:
            return Mpd.playlists.filter(match).slice(0, 20).map(p => ({ label: p, value: p }));
        }
    }
    readonly property string itemIcon: ["audio-x-generic-symbolic", "avatar-default-symbolic",
        "media-optical-symbolic", "view-list-symbolic"][mode]

    onResultsChanged: selected = 0
    Component.onCompleted: {
        Mpd.refresh();
        input.forceActiveFocus();
    }

    function close(): void { Panels.musicLauncherScreen = ""; }

    function play(index: int): void {
        const item = results[index];
        if (!item)
            return;
        close();
        [Mpd.playSong, Mpd.playArtist, Mpd.playAlbum, Mpd.playPlaylist][mode](item.value);
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: Theme.alpha("#000000", 0.3)
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell:music"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 320
        width: 544
        implicitHeight: content.implicitHeight + 32
        radius: 16
        color: Theme.surface

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            spacing: 4

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 48
                radius: 16
                color: Theme.surfaceContainer

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 8

                    Icon {
                        icon: "folder-music-symbolic"
                        size: 24
                    }
                    TextInput {
                        id: input
                        Layout.fillWidth: true
                        color: Theme.fgSurface
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                        clip: true

                        Keys.onEscapePressed: root.close()
                        Keys.onTabPressed: root.mode = (root.mode + 1) % root.modes.length
                        Keys.onBacktabPressed: root.mode = (root.mode + root.modes.length - 1) % root.modes.length
                        Keys.onDownPressed: root.selected = Math.min(root.selected + 1, root.results.length - 1)
                        Keys.onUpPressed: root.selected = Math.max(root.selected - 1, 0)
                        onAccepted: root.play(root.selected)

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !input.text
                            text: "Search music library"
                            color: Theme.fgSurfaceVariant
                        }
                    }
                }
            }

            // Mode bar: All Songs · Artists · Albums · Playlists
            Row {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 4
                Layout.bottomMargin: 4
                spacing: 6

                Repeater {
                    model: root.modes
                    Row {
                        required property string modelData
                        required property int index
                        spacing: 6
                        StyledText {
                            text: parent.modelData
                            font.pixelSize: 13
                            font.bold: parent.index === root.mode
                            color: parent.index === root.mode ? Theme.primary : Theme.fgSurface
                            opacity: parent.index === root.mode ? 1 : 0.4
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.mode = parent.parent.index;
                                    input.forceActiveFocus();
                                }
                            }
                        }
                        StyledText {
                            visible: parent.index < root.modes.length - 1
                            text: "·"
                            font.pixelSize: 13
                            opacity: 0.3
                        }
                    }
                }
            }

            Repeater {
                model: root.results

                Clickable {
                    id: result
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    implicitHeight: 48
                    radius: 16
                    border.width: 2
                    border.color: index === root.selected ? Theme.primary : Theme.surface
                    onClicked: root.play(index)

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 12

                        Icon {
                            icon: root.itemIcon
                            size: 32
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: result.modelData.label
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            StyledText {
                visible: root.query !== "" && root.results.length === 0
                Layout.alignment: Qt.AlignHCenter
                Layout.margins: 16
                text: "No results found"
                opacity: 0.6
            }
        }
    }
}
