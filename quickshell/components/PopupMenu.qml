import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.theme

// Simple dropdown menu below `anchorItem`. Closes on item click or outside click.
// entries: [{ text, enabled?: bool, separator?: bool, action?: function }]
PopupWindow {
    id: root

    required property Item anchorItem
    property var entries: []

    function open(): void { visible = true; }
    function close(): void { visible = false; }

    anchor.item: anchorItem
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.margins.top: 6
    implicitWidth: Math.max(220, column.implicitWidth + 12)
    implicitHeight: column.implicitHeight + 12
    color: "transparent"

    HyprlandFocusGrab {
        active: root.visible
        windows: [root]
        onCleared: root.close()
    }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Theme.surfaceContainer
        border.width: 1
        border.color: Theme.alpha(Theme.outline, 0.3)

        ColumnLayout {
            id: column
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2

            Repeater {
                model: root.entries

                Loader {
                    id: entry
                    required property var modelData
                    Layout.fillWidth: true
                    sourceComponent: modelData.separator ? separator : item

                    Component {
                        id: separator
                        Rectangle {
                            implicitHeight: 9
                            color: "transparent"
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width - 8
                                height: 1
                                color: Theme.alpha(Theme.outline, 0.3)
                            }
                        }
                    }

                    Component {
                        id: item
                        Clickable {
                            readonly property bool enabledEntry: entry.modelData.enabled ?? true
                            implicitWidth: label.implicitWidth + 24
                            implicitHeight: 32
                            radius: 8
                            opacity: enabledEntry ? 1 : 0.4
                            enabled: enabledEntry
                            onClicked: {
                                root.close();
                                entry.modelData.action?.();
                            }

                            StyledText {
                                id: label
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: entry.modelData.text
                                font.pixelSize: 14
                            }
                        }
                    }
                }
            }
        }
    }
}
