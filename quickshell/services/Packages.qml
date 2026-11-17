pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.theme

// Parcels from ~/Projects/package-tracker: its hourly timer writes
// packages.json (schema in that repo's docs/SCHEMA.md); this only reads it,
// watching for changes. Actions shell out to `pkgtrack`.
Singleton {
    id: root

    property var packages: []
    property string generatedAt: ""
    readonly property int count: packages.length
    readonly property bool busy: runner.running

    // Normalized status -> label, Papirus icon, Theme colour (see docs/SCHEMA.md).
    readonly property var statuses: ({
        label_created: { label: "Label created", icon: "document-new-symbolic", color: Theme.fgSurfaceVariant },
        in_transit: { label: "In transit", icon: "mail-send-symbolic", color: Theme.primary },
        out_for_delivery: { label: "Out for delivery", icon: "mark-location-symbolic", color: Theme.tertiary },
        available_for_pickup: { label: "Ready for pickup", icon: "find-location-symbolic", color: Theme.tertiary },
        delivered: { label: "Delivered", icon: "emblem-ok-symbolic", color: Theme.secondary },
        exception: { label: "Problem", icon: "dialog-warning-symbolic", color: Theme.error },
        returned: { label: "Returned", icon: "edit-undo-symbolic", color: Theme.error },
        unknown: { label: "Unknown", icon: "dialog-question-symbolic", color: Theme.outline }
    })

    function statusInfo(status: string): var {
        return statuses[status] ?? statuses.unknown;
    }

    // "In transit", or for carriers without a module yet "Unknown · carrier pending"
    // (or "In transit · tracking pending" when emails gave a status).
    function statusLabel(pkg: var): string {
        if (pkg.carrier_state === "supported")
            return statusInfo(pkg.status).label;
        const suffix = pkg.carrier_state === "failed" ? "unsupported" : "pending";
        return pkg.status === "unknown" ? `Unknown · carrier ${suffix}` : `${statusInfo(pkg.status).label} · tracking ${suffix}`;
    }

    // "Today", "Tomorrow", "Thu", "Oct 24" for an ETA date or timestamp.
    function formatDay(value: string): string {
        if (!value) return "";
        const d = new Date(value.length === 10 ? value + "T12:00:00" : value);
        const day = new Date(d.getFullYear(), d.getMonth(), d.getDate());
        const now = new Date();
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const diff = Math.round((day - today) / 86400000);
        if (diff === 0) return "Today";
        if (diff === 1) return "Tomorrow";
        if (diff === -1) return "Yesterday";
        if (diff > 1 && diff < 7) return Qt.formatDate(d, "ddd");
        return Qt.formatDate(d, "MMM d");
    }

    function formatTime(value: string): string {
        if (!value) return "";
        const d = new Date(value);
        return `${formatDay(value)} ${Qt.formatTime(d, "HH:mm")}`;
    }

    function openTracking(pkg: var): void {
        if (pkg.tracking_url)
            Quickshell.execDetached(["xdg-open", pkg.tracking_url]);
    }

    function pkgtrack(args: var): void {
        if (runner.running) return;
        runner.command = [Quickshell.env("HOME") + "/.local/bin/uv", "run", "--quiet", "--project", Config.expand(Config.packages.project), "pkgtrack"].concat(args);
        runner.running = true;
    }

    // Full run (scan + refresh) through the systemd unit, so it shares the timer's lock and log.
    function scanNow(): void {
        if (!runner.running) {
            runner.command = ["systemctl", "--user", "start", "package-tracker.service"];
            runner.running = true;
        }
    }
    function dismiss(pkg: var): void { pkgtrack(["remove", pkg.id]); }

    Process {
        id: runner
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) console.warn("Packages:", text.trim())
        }
    }

    // Fallback in case a change notification is missed.
    Timer {
        interval: 300000
        repeat: true
        running: true
        onTriggered: file.reload()
    }

    FileView {
        id: file
        path: Config.expand(Config.packages.file)
        watchChanges: true
        // The tracker replaces the file atomically (rename), so reload on any change.
        onFileChanged: reload()
        onLoaded: {
            try {
                const obj = JSON.parse(text());
                root.packages = obj.packages ?? [];
                root.generatedAt = obj.generated_at ?? "";
            } catch (e) {
                console.warn("Packages: cannot parse", path, e);
            }
        }
        onLoadFailed: root.packages = []
    }
}
