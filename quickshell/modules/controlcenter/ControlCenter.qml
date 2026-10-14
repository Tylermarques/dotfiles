import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.services
import qs.theme

// Right-hand panel on one screen. Created by ControlCenterLoader only while
// open; clicking outside the panel or pressing Esc closes it.
PanelWindow {
    id: root

    required property bool shown
    // Becomes true just after creation so the panel slides in.
    property bool slidIn: false

    Component.onCompleted: Qt.callLater(() => slidIn = true)
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.namespace: "quickshell:controlcenter"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    onShownChanged: if (!shown) menus.open = ""

    QtObject {
        id: menus
        property string open: ""
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Panels.closeControlCenter()
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Panels.closeControlCenter()
    }

    Rectangle {
        id: panel
        width: 448
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: 16
        radius: 16
        color: Theme.surface
        border.width: 1
        border.color: Theme.alpha(Theme.outline, 0.2)

        // Slide relative to the right edge, not via x: the window starts at
        // width 0, so an x binding would animate in from the left as it resizes.
        transform: Translate {
            x: root.shown && root.slidIn ? 0 : panel.width + 24
            Behavior on x {
                NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
            }
        }

        // Swallow clicks so they don't reach the close-on-outside-click area.
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Top section scrolls if menus grow taller than the screen allows.
            Flickable {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(top.implicitHeight + 32, panel.height * 0.7)
                contentHeight: top.implicitHeight + 32
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: top
                    x: 16
                    y: 16
                    width: parent.width - 32
                    spacing: 12

                    QuickSettings {
                        Layout.fillWidth: true
                        menuState: menus
                        onCloseRequested: Panels.closeControlCenter()
                    }
                    VolumeRow {
                        Layout.topMargin: 4
                        input: false
                        menuState: menus
                        onCloseRequested: Panels.closeControlCenter()
                    }
                    VolumeRow {
                        input: true
                        menuState: menus
                        onCloseRequested: Panels.closeControlCenter()
                    }
                    UserRow {
                        onCloseRequested: Panels.closeControlCenter()
                    }
                    Repeater {
                        model: Media.players
                        MediaCard {
                            required property var modelData
                            player: modelData
                        }
                    }
                }
            }

            NotificationCenter {
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }
}
