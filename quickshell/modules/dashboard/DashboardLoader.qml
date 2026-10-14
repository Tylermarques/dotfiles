import QtQuick
import Quickshell
import qs.services

// Creates the dashboard window for one screen only while it is open (plus the
// slide-out), and keeps SysStats polling only for that time.
Scope {
    id: root

    required property ShellScreen modelData
    readonly property bool shown: Panels.dashboardScreen === modelData.name

    onShownChanged: {
        SysStats.refs += shown ? 1 : -1;
        if (!shown)
            hideDelay.restart();
    }

    Timer {
        id: hideDelay
        interval: 320
    }

    LazyLoader {
        active: root.shown || hideDelay.running

        Dashboard {
            screen: root.modelData
            shown: root.shown
        }
    }
}
