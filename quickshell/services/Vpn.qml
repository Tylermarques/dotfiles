pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Quickshell.Networking has no VPN support yet, so this wraps nmcli:
// a long-lived `nmcli monitor` triggers a (debounced) re-list on any change.
Singleton {
    id: root

    property var connections: []    // [{ name, type, active }]
    readonly property var active: connections.find(c => c.active) ?? null
    readonly property bool connected: active !== null

    function toggle(name: string): void {
        const c = connections.find(x => x.name === name);
        if (c) Quickshell.execDetached(["nmcli", "connection", c.active ? "down" : "up", "id", name]);
    }

    function parse(text: string): void {
        const result = [];
        for (const line of text.split("\n")) {
            if (!line) continue;
            // nmcli -t escapes ':' inside fields as '\:'
            const fields = line.replace(/\\:/g, "\u0000").split(":").map(f => f.replace(/\u0000/g, ":"));
            const [name, type, active] = fields;
            if (type === "vpn" || type === "wireguard")
                result.push({ name, type, active: active === "yes" });
        }
        connections = result;
    }

    Process {
        id: list
        command: ["nmcli", "-t", "-f", "NAME,TYPE,ACTIVE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    Process {
        id: monitor
        command: ["nmcli", "monitor"]
        running: true
        stdout: SplitParser {
            onRead: debounce.restart()
        }
        onRunningChanged: if (!running) restart.start()
    }

    Timer {
        id: debounce
        interval: 300
        onTriggered: list.running = true
    }

    Timer {
        id: restart
        interval: 5000
        onTriggered: monitor.running = true
    }

    Component.onCompleted: list.running = true
}
