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
    property bool serviceStopping: false   // from the service (Stopping property)
    property bool stopRequested: false     // optimistic: set at click, before the service reports
    readonly property bool stopping: serviceStopping || stopRequested
    property bool isManual: false
    property string provider: ""
    property string title: ""
    property real startMs: 0
    property var failures: []
    readonly property bool hasFailures: failures.length > 0
    property var processing: null
    readonly property bool isProcessing: processing !== null && processing !== undefined && processing.meeting_id !== undefined
    property string lastError: ""   // clears itself after a few seconds

    function pickAndStart(): void { send("PickAndStartRecording", []); }
    function cancelPick(): void { send("CancelPick", []); }
    // Empty address = the focused window.
    function start(address: string): void { send("StartManualRecording", [address]); }
    // Without force only manual recordings stop.
    function stop(force: bool): void {
        stopRequested = true;
        stopGuard.restart();
        send("StopRecording", [force]);
    }

    function dismissFailures(): void { send("DismissFailures", []); }

    function send(method: string, args: var): void {
        if (!bridge.running) {
            setError("meeting-notes bridge is not running");
            return;
        }
        bridge.write(JSON.stringify({ call: method, args: args }) + "\n");
    }

    function setError(message: string): void {
        lastError = message;
        stopRequested = false;
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
            serviceStopping = !!msg.stopping;
            // The service now reports the real state; drop the optimistic flag.
            // Other state updates (failure/processing polls) must not clear it early.
            if (msg.stopping || !msg.isRecording)
                stopRequested = false;
            isManual = msg.isManual;
            provider = msg.provider;
            title = msg.title;
            startMs = msg.startMs;
            failures = msg.failures || [];
            processing = msg.processing || null;
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
            root.serviceStopping = false;
            root.stopRequested = false;
            root.failures = [];
            root.processing = null;
            restart.start();
        }
    }

    // Bring the bridge back if it dies (it only exits on its own on errors).
    Timer {
        id: restart
        interval: 5000
        onTriggered: bridge.running = true
    }

    // Safety net so the optimistic flag can never stick; the service flag stays
    // the source of truth for long stops.
    Timer {
        id: stopGuard
        interval: 30000
        onTriggered: root.stopRequested = false
    }

    Timer {
        id: errorClear
        interval: 4000
        onTriggered: root.lastError = ""
    }
}
