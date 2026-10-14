import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.components
import qs.config
import qs.services
import qs.theme

// Mute button + volume slider + arrow opening the output/input device picker.
ColumnLayout {
    id: root

    required property bool input
    required property QtObject menuState

    readonly property PwNode node: input ? Audio.source : Audio.sink
    readonly property bool muted: node?.audio?.muted ?? false
    readonly property string menuKey: input ? "volume-input" : "volume-output"
    readonly property bool menuOpen: menuState.open === menuKey

    signal closeRequested

    Layout.fillWidth: true
    spacing: 0

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Clickable {
            implicitWidth: 32
            implicitHeight: 32
            radius: 16
            onClicked: if (root.node?.audio) root.node.audio.muted = !root.muted
            Icon {
                anchors.centerIn: parent
                icon: root.input ? Audio.micIcon : Audio.speakerIcon
                size: 18
            }
        }
        Slider {
            Layout.fillWidth: true
            enabled: !root.muted
            value: root.muted ? 0 : (root.node?.audio?.volume ?? 0)
            onMoved: v => { if (root.node?.audio) root.node.audio.volume = v; }
        }
        Clickable {
            implicitWidth: 32
            implicitHeight: 32
            radius: 16
            onClicked: root.menuState.open = root.menuOpen ? "" : root.menuKey
            Icon {
                anchors.centerIn: parent
                icon: "pan-down-symbolic"
                size: 20
                rotation: root.menuOpen ? 180 : 0
                Behavior on rotation { NumberAnimation { duration: 200 } }
            }
        }
    }

    Expander {
        open: root.menuOpen

        MenuHeader {
            icon: root.input ? "microphone-sensitivity-high-symbolic" : "audio-headphones-symbolic"
            text: root.input ? "Sound Input" : "Sound Output"
        }
        Repeater {
            model: root.input ? Audio.sources : Audio.sinks
            MenuRow {
                required property PwNode modelData
                icon: "audio-card-symbolic"
                text: modelData.description || modelData.nickname || modelData.name
                checked: modelData === root.node
                onClicked: {
                    if (root.input) Pipewire.preferredDefaultAudioSource = modelData;
                    else Pipewire.preferredDefaultAudioSink = modelData;
                }
            }
        }
        Separator {}
        MenuRow {
            icon: "preferences-system-symbolic"
            text: "Sound Settings"
            onClicked: {
                Quickshell.execDetached([Config.apps.soundSettings]);
                root.closeRequested();
            }
        }
    }
}
