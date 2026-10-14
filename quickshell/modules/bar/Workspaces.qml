import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.components
import qs.config
import qs.theme

// Existing workspaces, labelled with the key that switches to them.
// Scroll moves to the previous/next workspace (not past maxScrollWorkspace).
Rectangle {
    id: root

    implicitWidth: row.implicitWidth + 16
    implicitHeight: 32
    radius: Theme.radius
    color: Theme.surface

    function label(id: int): string {
        return Config.bar.workspaceLabels[String(id)] ?? String(id);
    }

    function goTo(id: int): void {
        Hyprland.dispatch(Hyprland.usingLua ? `hl.dsp.focus({ workspace = ${id} })` : `workspace ${id}`);
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            const current = Hyprland.focusedWorkspace?.id ?? 1;
            const target = current + (wheel.angleDelta.y > 0 ? -1 : 1);
            if (target >= 1 && target <= Config.bar.maxScrollWorkspace)
                root.goTo(target);
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: Hyprland.workspaces.values.filter(w => w.id > 0).sort((a, b) => a.id - b.id)

            Clickable {
                id: ws

                required property HyprlandWorkspace modelData
                readonly property bool isFocused: Hyprland.focusedWorkspace === modelData

                Layout.preferredWidth: isFocused ? 36 : 22
                Layout.preferredHeight: 22
                radius: 11
                baseColor: isFocused ? Theme.primary : Theme.primaryContainer
                onClicked: root.goTo(modelData.id)

                Behavior on Layout.preferredWidth {
                    NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                }

                StyledText {
                    anchors.centerIn: parent
                    text: root.label(ws.modelData.id)
                    font.pixelSize: 12
                    font.bold: true
                    color: ws.isFocused ? Theme.fgPrimary : Theme.fgPrimaryContainer
                }
            }
        }
    }
}
