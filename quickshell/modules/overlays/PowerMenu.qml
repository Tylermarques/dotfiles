import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.components
import qs.services
import qs.theme

// Power off / reboot / suspend / sign out over a dimmed screen. Arrow keys or
// Tab move between buttons, Enter activates, Esc or a click outside closes.
PanelWindow {
    id: root

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: Theme.alpha("#000000", 0.5)
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell:powermenu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    readonly property var actions: [
        { text: "Power off", icon: "system-shutdown-symbolic", run: () => Quickshell.execDetached(["poweroff"]) },
        { text: "Reboot", icon: "system-reboot-symbolic", run: () => Quickshell.execDetached(["reboot"]) },
        { text: "Suspend", icon: "night-light-symbolic", run: () => Quickshell.execDetached(["sh", "-c", "systemctl suspend && hyprlock"]) },
        // Hyprland's Lua config has no `exit` dispatcher string; it's hl.dsp.exit().
        { text: "Sign out", icon: "system-log-out-symbolic", run: () => Hyprland.dispatch(Hyprland.usingLua ? "hl.dsp.exit()" : "exit") }
    ]

    property var buttons: []

    function close(): void { Panels.powerMenuScreen = ""; }
    function focusButton(index: int): void { buttons[index]?.forceActiveFocus(); }

    function activate(index: int): void {
        close();
        actions[index].run();
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.close()
    }

    Rectangle {
        anchors.centerIn: parent
        implicitWidth: grid.implicitWidth + 32
        implicitHeight: grid.implicitHeight + 32
        radius: 16
        color: Theme.surface

        MouseArea { anchors.fill: parent }

        GridLayout {
            id: grid
            anchors.centerIn: parent
            columns: 2
            rowSpacing: 16
            columnSpacing: 16

            Repeater {
                model: root.actions

                ColumnLayout {
                    id: entry
                    required property var modelData
                    required property int index
                    spacing: 8

                    Clickable {
                        id: button
                        Layout.alignment: Qt.AlignHCenter
                        implicitWidth: 128
                        implicitHeight: 128
                        radius: 64
                        focus: entry.index === 0
                        activeFocusOnTab: true
                        baseColor: activeFocus ? Theme.primary : "transparent"
                        onClicked: root.activate(entry.index)
                        Component.onCompleted: root.buttons[entry.index] = button

                        Keys.onReturnPressed: root.activate(entry.index)
                        Keys.onEnterPressed: root.activate(entry.index)
                        Keys.onSpacePressed: root.activate(entry.index)
                        Keys.onEscapePressed: root.close()
                        // 2x2 grid: left/right flip the column, up/down the row.
                        Keys.onLeftPressed: root.focusButton(entry.index ^ 1)
                        Keys.onRightPressed: root.focusButton(entry.index ^ 1)
                        Keys.onUpPressed: root.focusButton(entry.index ^ 2)
                        Keys.onDownPressed: root.focusButton(entry.index ^ 2)

                        Icon {
                            anchors.centerIn: parent
                            icon: entry.modelData.icon
                            size: 36
                            color: button.activeFocus ? Theme.surface : Theme.fgSurface
                        }
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: entry.modelData.text
                    }
                }
            }
        }
    }
}
