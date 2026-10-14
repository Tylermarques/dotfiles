import QtQuick
import Quickshell
import qs.services

// Creates the control center window for one screen only while it is open
// (plus the slide-out), so its lists, art and history cost nothing otherwise.
Scope {
    id: root

    required property ShellScreen modelData
    readonly property bool shown: Panels.controlCenterScreen === modelData.name

    onShownChanged: if (!shown) hideDelay.restart()

    Timer {
        id: hideDelay
        interval: 320
    }

    LazyLoader {
        active: root.shown || hideDelay.running

        ControlCenter {
            screen: root.modelData
            shown: root.shown
        }
    }
}
