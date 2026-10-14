pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// User settings, backed by config.json next to shell.qml.
// Edits to the file apply live; changes made from the UI are written back.
Singleton {
    id: root

    readonly property alias notifications: adapter.notifications
    readonly property alias appearance: adapter.appearance
    readonly property alias user: adapter.user
    readonly property alias recorder: adapter.recorder
    readonly property alias bar: adapter.bar
    readonly property alias meetingNotes: adapter.meetingNotes
    readonly property alias apps: adapter.apps

    function expand(path: string): string {
        return path.startsWith("~/") ? Quickshell.env("HOME") + path.slice(1) : path;
    }

    FileView {
        path: Quickshell.shellDir + "/config.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: adapter

            property JsonObject notifications: JsonObject {
                property bool dnd: false
                property int popupTimeoutMs: 5000
                property int maxPopups: 3
                property int historyCap: 200
                property list<string> noHistoryApps: ["agent-manager"]
            }
            property JsonObject appearance: JsonObject {
                property bool darkMode: true
                property string colorsFile: "~/.cache/quickshell/material/colors.json"
            }
            property JsonObject user: JsonObject {
                property string avatar: "/var/lib/AccountsService/icons/" + Quickshell.env("USER")
            }
            property JsonObject recorder: JsonObject {
                property string directory: "~/Videos"
                property string filename: "%Y-%m-%d_%H-%M-%S"
                property int fps: 60
            }
            property JsonObject bar: JsonObject {
                property int height: 44
                property var workspaceLabels: ({ "10": "0" })
                property int maxScrollWorkspace: 10
                property int nowPlayingMaxChars: 40
            }
            property JsonObject meetingNotes: JsonObject {
                property string webUrl: "http://127.0.0.1:8636"
                property int maxMenuWindows: 12
            }
            property JsonObject apps: JsonObject {
                property string terminal: "kitty"
                property string soundSettings: "pavucontrol"
                property string networkSettings: "nm-connection-editor"
            }
        }
    }
}
