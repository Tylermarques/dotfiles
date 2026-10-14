pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Open/closed state of the shell's overlays. Each holds the name of the screen
// it is shown on ("" = closed); overlays opened by keybind use the focused one.
Singleton {
    id: root

    property string controlCenterScreen: ""
    property string powerMenuScreen: ""
    property string musicLauncherScreen: ""
    property string osdScreen: ""

    readonly property string focusedScreen: Hyprland.focusedMonitor?.name ?? Quickshell.screens[0]?.name ?? ""

    function toggleControlCenter(screenName: string): void {
        controlCenterScreen = controlCenterScreen === screenName ? "" : screenName;
    }
    function closeControlCenter(): void { controlCenterScreen = ""; }

    function togglePowerMenu(): void {
        powerMenuScreen = powerMenuScreen ? "" : focusedScreen;
    }
    function toggleMusicLauncher(): void {
        musicLauncherScreen = musicLauncherScreen ? "" : focusedScreen;
    }

    // Volume OSD: shown on the focused screen, hidden 3 s after the last call.
    function showOsd(): void {
        osdScreen = focusedScreen;
        osdTimer.restart();
    }

    Timer {
        id: osdTimer
        interval: 3000
        onTriggered: root.osdScreen = ""
    }

    IpcHandler {
        target: "controlcenter"

        function toggle(): void { root.toggleControlCenter(root.focusedScreen); }
        function close(): void { root.closeControlCenter(); }
    }

    IpcHandler {
        target: "power"

        function toggle(): void { root.togglePowerMenu(); }
        function close(): void { root.powerMenuScreen = ""; }
    }

    IpcHandler {
        target: "music"

        function toggle(): void { root.toggleMusicLauncher(); }
        function close(): void { root.musicLauncherScreen = ""; }
    }

    IpcHandler {
        target: "osd"

        // Not "show": that collides with the `qs ipc show` subcommand.
        function popup(): void { root.showOsd(); }
    }
}
