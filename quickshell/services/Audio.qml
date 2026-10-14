pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property bool micMuted: source?.audio?.muted ?? false

    // Hardware devices (no app streams), for the output/input pickers.
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var sources: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream)

    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property string micIcon: {
        if (micMuted || micVolume <= 0) return "microphone-sensitivity-muted-symbolic";
        if (micVolume < 0.34) return "microphone-sensitivity-low-symbolic";
        if (micVolume < 0.67) return "microphone-sensitivity-medium-symbolic";
        return "microphone-sensitivity-high-symbolic";
    }

    readonly property string speakerIcon: {
        if (muted || volume <= 0) return "audio-volume-muted-symbolic";
        if (volume < 0.34) return "audio-volume-low-symbolic";
        if (volume < 0.67) return "audio-volume-medium-symbolic";
        return "audio-volume-high-symbolic";
    }

    // Default nodes must be tracked for their audio properties to be live.
    PwObjectTracker {
        objects: [root.sink, root.source]
    }
}
