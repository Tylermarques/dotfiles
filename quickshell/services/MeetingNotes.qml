pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// State of the meeting-notes capture service, via scripts/meetingnotes-bridge.py
// (a separate process, so D-Bus can never stall the shell). Methods are
// fire-and-forget; outcomes arrive as state updates or `lastError`.
Singleton {
    id: root

    property bool available: false
    property bool isRecording: false
    property bool pickerActive: false
    property bool isManual: false
    property string provider: ""
    property string title: ""
    property real startMs: 0
    property string lastError: ""   // clears itself after a few seconds

    function pickAndStart(): void { send("PickAndStartRecording", []); }
    function cancelPick(): void { send("CancelPick", []); }
    // Empty address = the focused window.
    function start(address: string): void { send("StartManualRecording", [address]); }
    // Without force only manual recordings stop.
    function stop(force: bool): void { send("StopRecording", [force]); }

    function send(method: string, args: var): void {
        if (!bridge.running) {
            setError("meeting-notes bridge is not running");
            return;
        }
        bridge.write(JSON.stringify({ call: method, args: args }) + "\n");
    }

    function setError(message: string): void {
        lastError = message;
        errorClear.restart();
    }

    function handle(line: string): void {
        let msg;
        try {
            msg = JSON.parse(line);
        } catch (e) {
            console.warn("MeetingNotes: bad bridge output", line);
            return;
        }
        if (msg.type === "error") {
            setError(msg.message);
        } else if (msg.type === "state") {
            available = msg.available;
            isRecording = msg.isRecording;
            pickerActive = msg.pickerActive;
            isManual = msg.isManual;
            provider = msg.provider;
            title = msg.title;
            startMs = msg.startMs;
        }
    }

    Process {
        id: bridge
        command: ["python3", Quickshell.shellDir + "/scripts/meetingnotes-bridge.py"]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => root.handle(line)
        }
        onExited: {
            root.available = false;
            restart.start();
        }
    }

    // Bring the bridge back if it dies (it only exits on its own on errors).
    Timer {
        id: restart
        interval: 5000
        onTriggered: bridge.running = true
    }

    Timer {
        id: errorClear
        interval: 4000
        onTriggered: root.lastError = ""
    }
}
