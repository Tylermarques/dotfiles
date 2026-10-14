import QtQuick
import QtQuick.Layouts
import qs.services
import qs.theme

// CPU and GPU on top; memory, storage and network below.
ColumnLayout {
    spacing: 12

    RowLayout {
        spacing: 12

        HeroCard {
            Layout.fillWidth: true
            icon: "cpu-symbolic"
            title: "CPU"
            subtitle: SysStats.cpuName
            usage: SysStats.cpuUsage
            temperature: SysStats.cpuTemp
            history: SysStats.cpuHistory
            accent: Theme.primary
        }
        HeroCard {
            Layout.fillWidth: true
            visible: SysStats.hasGpu
            icon: "video-display-symbolic"
            title: "GPU"
            subtitle: SysStats.gpuName
            usage: SysStats.gpuUsage
            temperature: SysStats.gpuTemp
            history: SysStats.gpuHistory
            extra: SysStats.gpuMemTotal > 0 ? `VRAM ${SysStats.formatBytes(SysStats.gpuMemUsed)} / ${SysStats.formatBytes(SysStats.gpuMemTotal)}` : ""
            accent: Theme.secondary
        }
    }

    RowLayout {
        spacing: 12

        MemoryCard {}
        StorageCard {}
        NetworkCard {}
    }
}
