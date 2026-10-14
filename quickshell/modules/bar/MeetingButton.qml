import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.components
import qs.config
import qs.services
import qs.theme

// Meeting-notes window capture.
//   idle        dim record icon; click opens the on-screen window picker
//   picking     pulsing; click cancels the picker
//   recording   red + elapsed time; click stops (manual recordings)
//   auto        provider-started (Meet, Discord); click opens the menu instead
//   error       brief flash when a command fails
//   unavailable service not running
// Right-click always opens the menu.
Clickable {
    id: root

    readonly property bool auto: MeetingNotes.isRecording && !MeetingNotes.isManual
    readonly property color fg: MeetingNotes.lastError ? Theme.error
        : auto ? Theme.tertiary
        : MeetingNotes.isRecording ? Theme.error
        : MeetingNotes.pickerActive ? Theme.primary
        : Theme.fgSurfaceVariant

    property real now: Date.now()

    implicitWidth: row.implicitWidth + 20
    implicitHeight: 30
    baseColor: MeetingNotes.lastError ? Theme.alpha(Theme.error, 0.25)
        : auto ? Theme.alpha(Theme.tertiary, 0.12)
        : MeetingNotes.isRecording ? Theme.alpha(Theme.error, 0.12)
        : Theme.surface
    border.width: MeetingNotes.pickerActive ? 1 : 0
    border.color: Theme.primary
    opacity: MeetingNotes.available ? 1 : 0.35
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onClicked: mouse => {
        if (mouse.button === Qt.RightButton)
            return openMenu();
        if (!MeetingNotes.available)
            return;
        if (MeetingNotes.pickerActive)
            MeetingNotes.cancelPick();
        else if (MeetingNotes.isRecording)
            MeetingNotes.isManual ? MeetingNotes.stop(false) : openMenu();
        else
            MeetingNotes.pickAndStart();
    }

    function elapsed(): string {
        if (!MeetingNotes.isRecording || !MeetingNotes.startMs)
            return "";
        const s = Math.max(0, Math.floor((now - MeetingNotes.startMs) / 1000));
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), sec = s % 60;
        const pad = n => String(n).padStart(2, "0");
        return h ? `${h}:${pad(m)}:${pad(sec)}` : `${pad(m)}:${pad(sec)}`;
    }

    function tooltip(): string {
        if (MeetingNotes.lastError) return MeetingNotes.lastError;
        if (!MeetingNotes.available) return "meeting-notes service is not running";
        if (MeetingNotes.pickerActive) return "Picking… click a window to record it (Esc or click here to cancel)";
        const title = MeetingNotes.title || "meeting";
        if (MeetingNotes.isRecording)
            return MeetingNotes.isManual ? `Recording ${title} · click to stop`
                : `Auto-recording ${title} · ends with the meeting (right-click to force stop)`;
        return "Record a window (click) · more options (right-click)";
    }

    function shorten(text: string): string {
        text = text.split(/\s+/).join(" ");
        return text.length <= 48 ? text : text.slice(0, 47) + "…";
    }

    function openMenu(): void {
        Hyprland.refreshToplevels();
        const recording = MeetingNotes.isRecording;
        const items = [];

        if (MeetingNotes.pickerActive) {
            items.push({ text: "Cancel picking", action: () => MeetingNotes.cancelPick() });
        } else if (!recording) {
            items.push({ text: "Pick a window on screen…", action: () => MeetingNotes.pickAndStart() });
            items.push({ text: "Record focused window", action: () => MeetingNotes.start("") });

            const windows = Hyprland.toplevels.values
                .map(t => ({
                    address: t.address.startsWith("0x") ? t.address : `0x${t.address}`,
                    cls: t.lastIpcObject?.class || t.wayland?.appId || "",
                    title: t.title,
                    ws: t.workspace?.id ?? 0,
                    hidden: t.lastIpcObject?.hidden ?? false
                }))
                .filter(w => w.title && !w.hidden && w.ws > 0)
                .sort((a, b) => a.ws - b.ws || a.cls.toLowerCase().localeCompare(b.cls.toLowerCase()))
                .slice(0, Config.meetingNotes.maxMenuWindows);
            if (windows.length) {
                items.push({ separator: true });
                for (const w of windows)
                    items.push({ text: shorten(`[${w.ws}] ${w.cls} — ${w.title}`), action: () => MeetingNotes.start(w.address) });
            }
        }

        items.push({ separator: true });
        items.push({
            text: MeetingNotes.isManual ? "Stop recording" : "Stop recording (force)",
            enabled: recording,
            action: () => MeetingNotes.stop(true)
        });
        items.push({ text: "Open Meeting Notes", action: () => Quickshell.execDetached(["xdg-open", Config.meetingNotes.webUrl]) });

        menu.entries = items;
        menu.open();
    }

    // Elapsed time only ticks while recording.
    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: MeetingNotes.isRecording
        onTriggered: root.now = Date.now()
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Icon {
            icon: "media-record-symbolic"
            size: 18
            color: root.fg

            SequentialAnimation on opacity {
                running: MeetingNotes.pickerActive
                loops: Animation.Infinite
                onRunningChanged: if (!running) parent.opacity = 1
                NumberAnimation { to: 0.15; duration: 500; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutSine }
            }
        }

        StyledText {
            visible: text !== ""
            text: root.elapsed()
            font.pixelSize: 16
        }
    }

    Tooltip {
        target: root
        shown: root.hovered && !menu.visible
        text: root.tooltip()
    }

    PopupMenu {
        id: menu
        anchorItem: root
    }
}
