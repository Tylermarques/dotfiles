import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import qs.components
import qs.config
import qs.services
import qs.theme

// Two-per-row toggles; a toggle's menu opens under its row (one at a time).
ColumnLayout {
    id: root

    // Shared with the volume rows so only one menu is open at a time.
    required property QtObject menuState

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property var keys: [
        Net.wifi ? "wifi" : "",
        Net.wired.length ? "wired" : "",
        Vpn.connections.length ? "vpn" : "",
        adapter ? "bluetooth" : "",
        "dnd", "dark", "record"
    ].filter(k => k)
    readonly property var rows: keys.reduce((acc, k, i) => (i % 2 ? acc[acc.length - 1].push(k) : acc.push([k]), acc), [])

    readonly property var toggles: ({
        wifi: wifiToggle, wired: wiredToggle, vpn: vpnToggle, bluetooth: bluetoothToggle,
        dnd: dndToggle, dark: darkToggle, record: recordToggle
    })
    readonly property var menus: ({
        wifi: wifiMenu, wired: wiredMenu, vpn: vpnMenu, bluetooth: bluetoothMenu, record: recordMenu
    })

    signal closeRequested

    function toggleMenu(key: string): void { menuState.open = menuState.open === key ? "" : key; }

    function runApp(command: string): void {
        Quickshell.execDetached([command]);
        root.closeRequested();
    }

    spacing: 8

    Repeater {
        model: root.rows

        ColumnLayout {
            id: row
            required property var modelData
            Layout.fillWidth: true
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                uniformCellSizes: true

                Repeater {
                    model: row.modelData
                    Loader {
                        required property string modelData
                        Layout.fillWidth: true
                        sourceComponent: root.toggles[modelData]
                    }
                }
                Item {
                    visible: row.modelData.length === 1
                    Layout.fillWidth: true
                }
            }

            Repeater {
                model: row.modelData.filter(k => root.menus[k])
                Loader {
                    required property string modelData
                    Layout.fillWidth: true
                    sourceComponent: root.menus[modelData]
                }
            }
        }
    }

    // ---- Wi-Fi ---------------------------------------------------------
    Component {
        id: wifiToggle
        Toggle {
            icon: Net.wifiConnected ? Net.wifiIcon : "network-wireless-symbolic"
            text: Net.wifiNetwork?.name ?? "Wi-Fi"
            active: Networking.wifiEnabled
            hasMenu: true
            menuOpen: root.menuState.open === "wifi"
            onClicked: root.toggleMenu("wifi")
        }
    }
    Component {
        id: wifiMenu
        Expander {
            id: menu
            property string askPskFor: ""
            open: root.menuState.open === "wifi"
            onOpenChanged: askPskFor = ""

            // Scan only while the list is visible.
            Binding {
                target: Net.wifi
                property: "scannerEnabled"
                value: menu.open
                when: Net.wifi !== null
            }

            MenuHeader {
                text: "Wi-Fi"
                showSwitch: true
                checked: Networking.wifiEnabled
                onToggled: v => Networking.wifiEnabled = v
            }
            Repeater {
                model: (Net.wifi?.networks.values ?? [])
                    .filter(n => n.name)
                    .sort((a, b) => b.connected - a.connected || b.signalStrength - a.signalStrength)
                ColumnLayout {
                    id: net
                    required property WifiNetwork modelData
                    Layout.fillWidth: true
                    spacing: 4

                    MenuRow {
                        icon: Net.strengthIcon(net.modelData.signalStrength)
                        text: net.modelData.name
                        checked: net.modelData.connected
                        trailing: net.modelData.stateChanging ? "…" : ""
                        onClicked: {
                            const n = net.modelData;
                            if (n.connected) n.disconnect();
                            else if (n.known || n.security === WifiSecurityType.Open) n.connect();
                            else menu.askPskFor = n.name;
                        }
                    }
                    PasswordField {
                        visible: menu.askPskFor === net.modelData.name
                        onAccepted: psk => {
                            net.modelData.connectWithPsk(psk);
                            menu.askPskFor = "";
                        }
                    }
                }
            }
            Separator {}
            MenuRow {
                icon: "preferences-system-symbolic"
                text: "Network Settings"
                onClicked: root.runApp(Config.apps.networkSettings)
            }
        }
    }

    // ---- Wired ---------------------------------------------------------
    Component {
        id: wiredToggle
        Toggle {
            icon: "network-wired-symbolic"
            text: "Wired"
            active: Net.wiredConnected
            hasMenu: true
            menuOpen: root.menuState.open === "wired"
            onClicked: root.toggleMenu("wired")
        }
    }
    Component {
        id: wiredMenu
        Expander {
            open: root.menuState.open === "wired"
            MenuHeader {
                icon: "network-wired-symbolic"
                text: "Wired connections"
            }
            Repeater {
                model: Net.wired
                MenuRow {
                    required property WiredDevice modelData
                    icon: "network-wired-symbolic"
                    text: modelData.name
                    trailing: modelData.connected ? "Disconnect" : "Connect"
                    onClicked: modelData.connected ? modelData.disconnect() : modelData.network?.connect()
                }
            }
            Separator {}
            MenuRow {
                icon: "preferences-system-symbolic"
                text: "Network Settings"
                onClicked: root.runApp(Config.apps.networkSettings)
            }
        }
    }

    // ---- VPN -----------------------------------------------------------
    Component {
        id: vpnToggle
        Toggle {
            icon: "network-vpn-symbolic"
            text: Vpn.active?.name ?? "VPN"
            active: Vpn.connected
            hasMenu: true
            menuOpen: root.menuState.open === "vpn"
            onClicked: root.toggleMenu("vpn")
        }
    }
    Component {
        id: vpnMenu
        Expander {
            open: root.menuState.open === "vpn"
            MenuHeader {
                icon: "network-vpn-symbolic"
                text: "VPN connections"
            }
            Repeater {
                model: Vpn.connections
                MenuRow {
                    required property var modelData
                    text: modelData.name
                    trailing: modelData.active ? "Disconnect" : "Connect"
                    onClicked: Vpn.toggle(modelData.name)
                }
            }
            Separator {}
            MenuRow {
                icon: "preferences-system-symbolic"
                text: "Network Manager"
                onClicked: root.runApp(Config.apps.networkSettings)
            }
        }
    }

    // ---- Bluetooth -----------------------------------------------------
    Component {
        id: bluetoothToggle
        Toggle {
            readonly property var connected: (root.adapter?.devices.values ?? []).filter(d => d.connected)
            icon: "bluetooth-active-symbolic"
            text: connected.length === 0 ? "Bluetooth"
                : connected.length === 1 ? (connected[0].name || connected[0].deviceName)
                : `${connected.length} devices`
            active: root.adapter?.enabled ?? false
            hasMenu: true
            menuOpen: root.menuState.open === "bluetooth"
            onClicked: root.toggleMenu("bluetooth")
        }
    }
    Component {
        id: bluetoothMenu
        Expander {
            id: btMenu
            open: root.menuState.open === "bluetooth"

            // Discover new devices only while the list is open.
            Binding {
                target: root.adapter
                property: "discovering"
                value: btMenu.open && root.adapter.enabled
                when: root.adapter !== null
            }

            MenuHeader {
                text: "Bluetooth"
                showSwitch: true
                checked: root.adapter?.enabled ?? false
                onToggled: v => root.adapter.enabled = v
            }
            Repeater {
                // Paired devices, plus up to 8 nearby ones that have a real name
                // (many only advertise their address).
                model: {
                    const all = root.adapter?.devices.values ?? [];
                    const named = d => d.name && d.name.replace(/-/g, ":").toUpperCase() !== d.address.toUpperCase();
                    const paired = all.filter(d => d.paired).sort((a, b) => b.connected - a.connected);
                    return [...paired, ...all.filter(d => !d.paired && named(d)).slice(0, 8)];
                }
                MenuRow {
                    required property BluetoothDevice modelData
                    icon: modelData.icon || "bluetooth-symbolic"
                    text: modelData.name || modelData.deviceName || modelData.address
                    checked: modelData.connected
                    trailing: modelData.pairing || modelData.state === BluetoothDeviceState.Connecting ? "…"
                        : modelData.paired ? "" : "Pair"
                    onClicked: modelData.connected ? modelData.disconnect()
                        : modelData.paired ? modelData.connect() : modelData.pair()
                }
            }
        }
    }

    // ---- Do not disturb / dark mode ------------------------------------
    Component {
        id: dndToggle
        Toggle {
            icon: Notifs.dnd ? "notification-disabled-symbolic" : "notification-symbolic"
            text: Notifs.dnd ? "Silent" : "Noisy"
            active: Notifs.dnd
            onClicked: Notifs.setDnd(!Notifs.dnd)
        }
    }
    Component {
        id: darkToggle
        Toggle {
            icon: "night-light-symbolic"
            text: "Dark"
            active: Config.appearance.darkMode
            onClicked: ThemeControl.setDarkMode(!Config.appearance.darkMode)
        }
    }

    // ---- Screen recording ----------------------------------------------
    Component {
        id: recordToggle
        Toggle {
            icon: "media-record-symbolic"
            text: "Recording"
            active: Recorder.active
            hasMenu: !Recorder.active
            menuOpen: root.menuState.open === "record"
            onClicked: Recorder.active ? Recorder.stop() : root.toggleMenu("record")
        }
    }
    Component {
        id: recordMenu
        Expander {
            id: rec
            property bool withAudio: false
            property string audio: "output"
            readonly property var audioLabels: [["output", "Internal audio"], ["input", "Microphone"], ["both", "Both sources"]]
            open: root.menuState.open === "record"

            Icon {
                Layout.alignment: Qt.AlignHCenter
                icon: "media-record-symbolic"
                size: 36
                color: Theme.error
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "Start recording?"
                font.pixelSize: 19
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                spacing: 10

                Icon { icon: "microphone-sensitivity-medium-symbolic" }
                StyledText {
                    Layout.fillWidth: true
                    text: "Record audio"
                }
                Switch {
                    checked: rec.withAudio
                    onToggled: v => rec.withAudio = v
                }
            }
            RowLayout {
                visible: rec.withAudio
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: rec.audioLabels
                    Clickable {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 30
                        radius: 15
                        baseColor: rec.audio === modelData[0] ? Theme.secondaryContainer : "transparent"
                        border.width: 1
                        border.color: Theme.alpha(Theme.outline, 0.5)
                        onClicked: rec.audio = modelData[0]
                        StyledText {
                            anchors.centerIn: parent
                            text: parent.modelData[1]
                            font.pixelSize: 13
                        }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 12
                spacing: 8

                Clickable {
                    implicitWidth: 90
                    implicitHeight: 32
                    radius: 16
                    border.width: 1
                    border.color: Theme.primary
                    onClicked: root.menuState.open = ""
                    StyledText { anchors.centerIn: parent; text: "Cancel" }
                }
                Item { Layout.fillWidth: true }
                Clickable {
                    implicitWidth: 150
                    implicitHeight: 32
                    radius: 16
                    baseColor: Theme.primary
                    onClicked: {
                        root.menuState.open = "";
                        root.closeRequested();
                        Recorder.start(rec.withAudio ? rec.audio : "none");
                    }
                    StyledText { anchors.centerIn: parent; text: "Start recording"; color: Theme.surface }
                }
            }
        }
    }
}
