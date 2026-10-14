pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU, GPU, memory, storage, network and uptime for the dashboard. Polls every
// 2 s, but only while something holds a ref (`SysStats.refs++` on open, `--`
// on close), so it costs nothing while the dashboard is closed.
Singleton {
    id: root

    property int refs: 0
    readonly property int historyLength: 30

    // CPU
    property string cpuName: ""
    property real cpuUsage: 0            // 0..1
    property real cpuTemp: NaN           // °C, NaN when no sensor
    property var cpuHistory: []
    // GPU (NVIDIA via nvidia-smi; gpuName stays "" when there is none)
    property string gpuName: ""
    property real gpuUsage: 0
    property real gpuTemp: NaN
    property real gpuMemUsed: 0          // bytes
    property real gpuMemTotal: 0
    property var gpuHistory: []
    readonly property bool hasGpu: gpuName !== "" && gpuName !== "none"
    // Memory (bytes)
    property real memUsed: 0
    property real memTotal: 0
    readonly property real memUsage: memTotal > 0 ? memUsed / memTotal : 0
    property real swapUsed: 0
    property real swapTotal: 0
    // Storage: [{ mount, used, total }] for real filesystems, "/" first
    property var disks: []
    readonly property var rootDisk: disks.find(d => d.mount === "/") ?? disks[0] ?? null
    readonly property real diskUsage: rootDisk && rootDisk.total > 0 ? rootDisk.used / rootDisk.total : 0
    // Network (bytes/s across physical interfaces; totals since the first sample)
    property real netDown: 0
    property real netUp: 0
    property real netDownTotal: 0
    property real netUpTotal: 0
    property var netDownHistory: []
    property var netUpHistory: []
    // Uptime in seconds
    property real uptime: 0

    property var lastCpu: null
    property var lastNet: null
    property real lastNetTime: 0
    property string cpuTempPath: ""

    function push(list: var, value: real): var {
        const next = list.concat([value]);
        return next.length > historyLength ? next.slice(next.length - historyLength) : next;
    }

    function formatBytes(bytes: real): string {
        const units = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (bytes >= 1024 && i < units.length - 1) {
            bytes /= 1024;
            i++;
        }
        return `${bytes.toFixed(bytes >= 100 || i === 0 ? 0 : 1)} ${units[i]}`;
    }

    function formatUptime(seconds: real): string {
        const d = Math.floor(seconds / 86400);
        const h = Math.floor(seconds % 86400 / 3600);
        const m = Math.floor(seconds % 3600 / 60);
        const parts = [];
        if (d) parts.push(`${d} day${d === 1 ? "" : "s"}`);
        if (h) parts.push(`${h} hour${h === 1 ? "" : "s"}`);
        if (!d && (m || !h)) parts.push(`${m} minute${m === 1 ? "" : "s"}`);
        return parts.join(", ");
    }

    function poll(): void {
        stat.reload();
        meminfo.reload();
        netdev.reload();
        uptimeFile.reload();
        if (cpuTempPath)
            cpuTempFile.reload();
        if (!df.running)
            df.running = true;
        if (gpuName !== "none" && !nvidia.running)
            nvidia.running = true;
    }

    Timer {
        interval: 2000
        repeat: true
        triggeredOnStart: true
        running: root.refs > 0
        onTriggered: root.poll()
    }

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = f[3] + f[4];
            const total = f.reduce((a, b) => a + b, 0);
            if (root.lastCpu) {
                const dt = total - root.lastCpu.total;
                root.cpuUsage = dt > 0 ? 1 - (idle - root.lastCpu.idle) / dt : 0;
                root.cpuHistory = root.push(root.cpuHistory, root.cpuUsage);
            }
            root.lastCpu = { idle, total };
        }
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            const kb = {};
            for (const line of text().split("\n")) {
                const m = line.match(/^(\w+):\s+(\d+)/);
                if (m) kb[m[1]] = Number(m[2]) * 1024;
            }
            root.memTotal = kb.MemTotal ?? 0;
            root.memUsed = root.memTotal - (kb.MemAvailable ?? 0);
            root.swapTotal = kb.SwapTotal ?? 0;
            root.swapUsed = root.swapTotal - (kb.SwapFree ?? 0);
        }
    }

    FileView {
        id: netdev
        path: "/proc/net/dev"
        onLoaded: {
            let rx = 0, tx = 0;
            for (const line of text().split("\n").slice(2)) {
                const [name, rest] = line.split(":");
                if (!rest || !/^\s*(en|eth|wl|ww)/.test(name)) continue;
                const f = rest.trim().split(/\s+/).map(Number);
                rx += f[0];
                tx += f[8];
            }
            const now = Date.now();
            if (root.lastNet) {
                const dt = (now - root.lastNetTime) / 1000;
                root.netDown = Math.max(0, rx - root.lastNet.rx) / dt;
                root.netUp = Math.max(0, tx - root.lastNet.tx) / dt;
                root.netDownTotal += Math.max(0, rx - root.lastNet.rx);
                root.netUpTotal += Math.max(0, tx - root.lastNet.tx);
                root.netDownHistory = root.push(root.netDownHistory, root.netDown);
                root.netUpHistory = root.push(root.netUpHistory, root.netUp);
            }
            root.lastNet = { rx, tx };
            root.lastNetTime = now;
        }
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        onLoaded: root.uptime = parseFloat(text())
    }

    FileView {
        id: cpuTempFile
        path: root.cpuTempPath
        onLoaded: root.cpuTemp = parseInt(text()) / 1000
    }

    // Static bits, read once: CPU model and which hwmon sensor is the CPU.
    Process {
        running: true
        command: ["sh", "-c", `
            grep -m1 'model name' /proc/cpuinfo | cut -d: -f2-
            for h in /sys/class/hwmon/hwmon*; do
                case "$(cat "$h/name")" in k10temp|zenpower|coretemp) echo "$h/temp1_input"; break;; esac
            done`]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                root.cpuName = (lines[0] ?? "").trim().replace(/\s+\d+-Core Processor$/, "");
                root.cpuTempPath = lines[1] ?? "";
            }
        }
    }

    Process {
        id: df
        command: ["df", "-B1", "--output=target,size,used", "-x", "tmpfs", "-x", "devtmpfs", "-x", "efivarfs", "-x", "overlay", "-x", "squashfs"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = new Set();
                const disks = [];
                for (const line of text.trim().split("\n").slice(1)) {
                    const [mount, size, used] = line.trim().split(/\s+/);
                    // Btrfs subvolumes and bind mounts repeat the same device's numbers.
                    const key = `${size}:${used}`;
                    if (Number(size) < 1e9 || seen.has(key)) continue;
                    seen.add(key);
                    disks.push({ mount, total: Number(size), used: Number(used) });
                }
                disks.sort((a, b) => (a.mount === "/" ? -1 : b.mount === "/" ? 1 : a.mount.localeCompare(b.mount)));
                root.disks = disks;
            }
        }
    }

    Process {
        id: nvidia
        command: ["nvidia-smi", "--query-gpu=name,utilization.gpu,temperature.gpu,memory.used,memory.total", "--format=csv,noheader,nounits"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split("\n")[0]?.split(",").map(s => s.trim()) ?? [];
                if (f.length < 5) return;
                root.gpuName = f[0].replace(/^NVIDIA\s+/, "");
                root.gpuUsage = Number(f[1]) / 100;
                root.gpuTemp = Number(f[2]);
                root.gpuMemUsed = Number(f[3]) * 1048576;
                root.gpuMemTotal = Number(f[4]) * 1048576;
                root.gpuHistory = root.push(root.gpuHistory, root.gpuUsage);
            }
        }
        // No NVIDIA GPU (or driver): stop asking.
        onExited: code => { if (code !== 0) root.gpuName = "none"; }
    }
}
