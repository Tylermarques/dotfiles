import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
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
//   stopping    "Stopping…", counter hidden, clicks ignored until the stop completes or fails
//   error       brief flash when a command fails
//   unavailable service not running
//   processing  ring around the icon fills by pipeline stage
// Right-click always opens the menu.
Clickable {
    id: root

    readonly property bool auto: MeetingNotes.isRecording && !MeetingNotes.isManual
    readonly property color fg: MeetingNotes.lastError ? Theme.error
        : MeetingNotes.stopping ? Theme.fgSurfaceVariant
        : auto ? Theme.tertiary
        : MeetingNotes.isRecording ? Theme.error
        : MeetingNotes.pickerActive ? Theme.primary
        : Theme.fgSurfaceVariant

    property real now: Date.now()

    implicitWidth: row.implicitWidth + 20
    implicitHeight: 30
    baseColor: MeetingNotes.lastError ? Theme.alpha(Theme.error, 0.25)
        : MeetingNotes.stopping ? Theme.alpha(Theme.error, 0.06)
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
        if (MeetingNotes.stopping)
            return;
        if (MeetingNotes.pickerActive)
            MeetingNotes.cancelPick();
        else if (MeetingNotes.isRecording)
            MeetingNotes.isManual ? MeetingNotes.stop(false) : openMenu();
        else
            MeetingNotes.pickAndStart();
    }

    function label(): string {
        if (MeetingNotes.stopping) return "Stopping…";
        return elapsed();
    }

    function elapsed(): string {
        if (!MeetingNotes.isRecording || !MeetingNotes.startMs)
            return "";
        const s = Math.max(0, Math.floor((now - MeetingNotes.startMs) / 1000));
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), sec = s % 60;
        const pad = n => String(n).padStart(2, "0");
        return h ? `${h}:${pad(m)}:${pad(sec)}` : `${pad(m)}:${pad(sec)}`;
    }

    function failureText(f): string {
        const title = f.title ? ` (${shorten(f.title)})` : "";
        if (f.kind === "export") {
            const count = f.failure_count > 1 ? ` (×${f.failure_count})` : "";
            return `Export blocked on meeting ${f.meeting_id}${title} since ${Qt.formatTime(new Date(f.first_failed_at), "hh:mm")}: ${f.error}${count}`;
        }
        if (f.kind === "stalled")
            return `Meeting ${f.meeting_id}${title}: ${f.error}`;
        return `Transcription failed for meeting ${f.meeting_id}${title}: ${f.error}`;
    }

    function failureLines(): string {
        const fs = MeetingNotes.failures;
        const lines = fs.slice(0, 3).map(f => failureText(f));
        if (fs.length > 3) lines.push(`+${fs.length - 3} more`);
        return lines.join("\n");
    }

    function tooltip(): string {
        if (MeetingNotes.lastError) return MeetingNotes.lastError;
        const parts = [];
        if (MeetingNotes.hasFailures) parts.push(failureLines());
        if (MeetingNotes.isProcessing) parts.push(processingLines());
        parts.push(baseTooltip());
        return parts.filter(p => p !== "").join("\n");
    }

    function processingHead(): string {
        if (!MeetingNotes.isProcessing) return "";
        const p = MeetingNotes.processing;
        return `Meeting ${p.meeting_id}${p.title ? " (" + shorten(p.title) + ")" : ""} · ${p.label}`;
    }

    function processingLines(): string {
        if (!MeetingNotes.isProcessing) return "";
        const p = MeetingNotes.processing;
        const q = p.queued ? ` · queued: ${p.queued} more` : "";
        return `${processingHead()}\nstep ${p.step}/${p.total} · ~${Math.round((p.fraction || 0) * 100)}%${q}`;
    }

    function baseTooltip(): string {
        if (!MeetingNotes.available) return "meeting-notes service is not running";
        if (MeetingNotes.pickerActive) return "Picking… click a window to record it (Esc or click here to cancel)";
        const title = MeetingNotes.title || "meeting";
        if (MeetingNotes.stopping) return "Stopping recording… saving the file";
        if (MeetingNotes.isRecording)
            return MeetingNotes.isManual ? `Recording ${title} · click to stop`
                : `Auto-recording ${title} · ends with the meeting (right-click to force stop)`;
        return "Record a window (click) · more options (right-click)";
    }

    function shorten(text: string, max): string {
        text = text.split(/\s+/).join(" ");
        if (max === undefined || max === null) max = 48;
        return text.length <= max ? text : text.slice(0, max - 1) + "…";
    }

    function openMenu(): void {
        Hyprland.refreshToplevels();
        const recording = MeetingNotes.isRecording;
        const items = [];

        if (MeetingNotes.isProcessing) {
            items.push({ text: shorten(processingHead(), 80), enabled: false });
            items.push({ separator: true });
        }

        if (MeetingNotes.hasFailures) {
            for (const f of MeetingNotes.failures.slice(0, 5))
                items.push({ text: shorten(failureText(f), 80), enabled: false });
            items.push({
                text: "Dismiss transcription failures",
                enabled: MeetingNotes.failures.some(f => f.kind === "transcription"),
                action: () => MeetingNotes.dismissFailures()
            });
            items.push({ separator: true });
        }

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
            text: MeetingNotes.stopping ? "Stopping…"
                : (MeetingNotes.isManual ? "Stop recording" : "Stop recording (force)"),
            enabled: recording && !MeetingNotes.stopping,
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
        running: MeetingNotes.isRecording && !MeetingNotes.stopping
        onTriggered: root.now = Date.now()
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Item {
            implicitWidth: 18
            implicitHeight: 18

            Icon {
                anchors.centerIn: parent
                icon: "media-record-symbolic"
                size: 18
                color: root.fg

                SequentialAnimation on opacity {
                    running: MeetingNotes.pickerActive || MeetingNotes.stopping
                    loops: Animation.Infinite
                    onRunningChanged: if (!running) parent.opacity = 1
                    NumberAnimation { to: 0.15; duration: 500; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 500; easing.type: Easing.InOutSine }
                }
            }

            // Processing ring: fills clockwise by cumulative stage weight.
            Shape {
                id: ring
                visible: MeetingNotes.isProcessing
                z: 0
                anchors.centerIn: parent
                width: 26
                height: 26
                preferredRendererType: Shape.CurveRenderer
                property real fraction: MeetingNotes.isProcessing ? (MeetingNotes.processing.fraction || 0) : 0
                Behavior on fraction { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }

                ShapePath {
                    strokeColor: Theme.alpha(Theme.outline, 0.35)
                    strokeWidth: 2
                    fillColor: "transparent"
                    PathAngleArc { centerX: 13; centerY: 13; radiusX: 12; radiusY: 12; startAngle: 0; sweepAngle: 360 }
                }
                ShapePath {
                    strokeColor: Theme.primary
                    strokeWidth: 2
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc { centerX: 13; centerY: 13; radiusX: 12; radiusY: 12; startAngle: -90; sweepAngle: 360 * ring.fraction }
                }
            }

            // Failed-runs badge: white "!" in a red circle, shown in every state.
            Rectangle {
                visible: MeetingNotes.hasFailures
                z: 1
                width: 11
                height: 11
                radius: 5.5
                color: "#e53935"
                border.width: 1
                border.color: Theme.surface
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: -3
                anchors.rightMargin: -4

                Text {
                    anchors.centerIn: parent
                    text: "!"
                    color: "white"
                    font.bold: true
                    font.pixelSize: 9
                }
            }
        }

        StyledText {
            visible: text !== ""
            text: root.label()
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
