pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Screen recorder around gpu-screen-recorder (desktop portal picks the source).
// Keybinds drive it with `qs ipc call recorder start|stop|pause|resume`.
Singleton {
    id: root

    readonly property bool active: proc.running
    property bool paused: false
    property string file: ""

    // Values for start(audio); also listed in the control center.
    readonly property var audioSources: ({
        "none": "",
        "output": "default_output",
        "input": "default_input",
        "both": "default_output|default_input"
    })

    function start(audio: string): void {
        if (proc.running)
            return;
        const dir = Config.expand(Config.recorder.directory);
        file = `${dir}/${strftime(Config.recorder.filename, new Date())}.mp4`;

        const cmd = ["gpu-screen-recorder", "-w", "portal", "-o", file];
        if (Config.recorder.fps)
            cmd.push("-f", String(Config.recorder.fps));
        const source = audioSources[audio] ?? "";
        if (source)
            cmd.push("-a", source);

        paused = false;
        proc.command = cmd;
        proc.running = true;
    }

    function stop(): void {
        if (proc.running)
            proc.signal(2); // SIGINT: finish and save the file
    }

    function setPaused(value: bool): void {
        if (proc.running && paused !== value) {
            proc.signal(12); // SIGUSR2 toggles pause
            paused = value;
        }
    }

    // Minimal strftime for the filename pattern in config.json (%Y %m %d %H %M %S).
    function strftime(pattern: string, d: date): string {
        const pad = n => String(n).padStart(2, "0");
        const parts = { Y: d.getFullYear(), m: pad(d.getMonth() + 1), d: pad(d.getDate()),
            H: pad(d.getHours()), M: pad(d.getMinutes()), S: pad(d.getSeconds()), "%": "%" };
        return pattern.replace(/%(.)/g, (m, c) => parts[c] ?? m);
    }

    Process {
        id: proc
        stderr: StdioCollector { id: err }
        onExited: code => {
            root.paused = false;
            if (code === 0)
                Quickshell.execDetached(["notify-send", "-a", "Screen recorder", "-i", "media-record-symbolic",
                    "Recording saved", root.file]);
            else if (code !== 60) // 60 = portal dialog cancelled
                Quickshell.execDetached(["notify-send", "-a", "Screen recorder", "-u", "critical",
                    "Recording failed", err.text.trim().split("\n").slice(-3).join("\n")]);
        }
    }

    IpcHandler {
        target: "recorder"

        function start(): void { root.start("none"); }
        function startWithAudio(audio: string): void { root.start(audio); }
        function stop(): void { root.stop(); }
        function pause(): void { root.setPaused(true); }
        function resume(): void { root.setPaused(false); }
        function toggle(): void { root.active ? root.stop() : root.start("none"); }
    }
}
