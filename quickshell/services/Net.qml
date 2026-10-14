pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

Singleton {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wifi: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wired: devices.filter(d => d.type === DeviceType.Wired && d.nmManaged)

    readonly property bool wifiConnected: wifi?.connected ?? false
    readonly property bool wiredConnected: wired.some(d => d.connected)
    readonly property var wifiNetwork: wifi ? wifi.networks.values.find(n => n.connected) ?? null : null

    // Same rule as the Ignis pill: show a device type only when it exists and
    // either the other type is down or this one is up.
    readonly property bool showWifi: wifi !== null && (!wiredConnected || wifiConnected)
    readonly property bool showWired: wired.length > 0 && (!wifiConnected || wiredConnected)

    readonly property string wifiIcon: !Networking.wifiEnabled ? "network-wireless-offline-symbolic"
        : !wifiNetwork ? "network-wireless-disconnected-symbolic"
        : strengthIcon(wifiNetwork.signalStrength)

    function strengthIcon(strength: real): string {
        const s = strength > 1 ? strength / 100 : strength;
        if (s > 0.8) return "network-wireless-signal-excellent-symbolic";
        if (s > 0.55) return "network-wireless-signal-good-symbolic";
        if (s > 0.3) return "network-wireless-signal-ok-symbolic";
        return "network-wireless-signal-weak-symbolic";
    }
    readonly property string wiredIcon: wiredConnected ? "network-wired-symbolic" : "network-wired-disconnected-symbolic"
}
