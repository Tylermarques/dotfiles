//@ pragma UseQApplication
//@ pragma IconTheme Papirus-Dark

import QtQuick
import Quickshell
import qs.modules.bar
import qs.modules.controlcenter
import qs.modules.dashboard
import qs.modules.notifications
import qs.modules.overlays
import qs.services

ShellRoot {
    // Singletons are created on first use; these must exist from the start
    // because their IPC handlers are called from outside (artwall, keybinds).
    readonly property var eagerServices: [ThemeControl, Recorder, Panels]

    Variants {
        model: Quickshell.screens

        Bar {}
    }

    Variants {
        model: Quickshell.screens

        Popups {}
    }

    Variants {
        model: Quickshell.screens

        ControlCenterLoader {}
    }

    Variants {
        model: Quickshell.screens

        DashboardLoader {}
    }

    Overlays {}
}
