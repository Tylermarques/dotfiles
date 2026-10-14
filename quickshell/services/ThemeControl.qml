pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Runs scripts/material.py (in its own process) to regenerate the Material
// palette; Theme then picks up the new colors.json on its own.
//   qs ipc call theme generate /path/to/image
//   qs ipc call theme setDarkMode true|false
Singleton {
    id: root

    function generate(image: string): void {
        run(["generate", Config.expand(image)].concat(Config.appearance.darkMode ? [] : ["--light"]));
    }

    function setDarkMode(dark: bool): void {
        Config.appearance.darkMode = dark;
        run(["mode", dark ? "dark" : "light"]);
    }

    function run(args: var): void {
        proc.command = ["python3", Quickshell.shellDir + "/scripts/material.py"].concat(args);
        proc.running = true;
    }

    Process {
        id: proc
        stderr: StdioCollector { id: err }
        onExited: code => {
            if (code === 0)
                return;
            // A failed dark/light switch leaves the old palette, so flip the setting back.
            if (proc.command[2] === "mode")
                Config.appearance.darkMode = proc.command[3] !== "dark";
            Quickshell.execDetached(["notify-send", "-a", "Theme", "Couldn't regenerate colours",
                    err.text.trim().split("\n").slice(-2).join("\n")]);
        }
    }

    IpcHandler {
        target: "theme"

        function generate(image: string): void { root.generate(image); }
        function setDarkMode(dark: bool): void { root.setDarkMode(dark); }
    }
}
