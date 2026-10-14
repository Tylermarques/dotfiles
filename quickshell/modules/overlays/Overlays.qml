import QtQuick
import Quickshell
import qs.services

// Keybind-driven overlays, each created on the focused screen only while open.
Scope {
    LazyLoader {
        active: Panels.osdScreen !== ""
        Osd {
            screen: Quickshell.screens.find(s => s.name === Panels.osdScreen) ?? null
        }
    }

    LazyLoader {
        active: Panels.powerMenuScreen !== ""
        PowerMenu {
            screen: Quickshell.screens.find(s => s.name === Panels.powerMenuScreen) ?? null
        }
    }

    LazyLoader {
        active: Panels.musicLauncherScreen !== ""
        MusicLauncher {
            screen: Quickshell.screens.find(s => s.name === Panels.musicLauncherScreen) ?? null
        }
    }
}
