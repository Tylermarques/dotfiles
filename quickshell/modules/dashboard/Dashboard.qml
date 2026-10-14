import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.services
import qs.theme

// Drop-down under the centre of the bar with Dashboard / Media / Performance
// tabs (after Caelestia's dashboard). Only the card takes input; the rest of
// the window lets clicks through.
PanelWindow {
    id: root

    required property bool shown
    property bool slidIn: false
    readonly property var tabs: [
        { label: "Dashboard", icon: "view-grid-symbolic" },
        { label: "Media", icon: "audio-x-generic-symbolic" },
        { label: "Performance", icon: "utilities-system-monitor-symbolic" }
    ]

    Component.onCompleted: Qt.callLater(() => slidIn = true)

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: card.implicitHeight + 24
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    mask: Region { item: card }
    WlrLayershell.namespace: "quickshell:dashboard"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: shown && Panels.dashboardPinned ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    function setTab(index: int): void {
        Panels.dashboardTab = (index + tabs.length) % tabs.length;
    }

    // Hover-opened: close shortly after the pointer leaves both card and bar.
    readonly property bool keepOpen: Panels.dashboardPinned || cardHover.hovered || Panels.dashboardBarHovered
    onKeepOpenChanged: keepOpen ? closeTimer.stop() : closeTimer.restart()
    Timer {
        id: closeTimer
        interval: 300
        onTriggered: if (!root.keepOpen) Panels.closeDashboard()
    }

    Rectangle {
        id: card

        readonly property Item page: pages.children[Panels.dashboardTab] ?? null

        anchors.horizontalCenter: parent.horizontalCenter
        y: root.shown && root.slidIn ? 0 : -height - 8
        opacity: root.shown && root.slidIn ? 1 : 0
        implicitWidth: Math.max(tabBar.implicitWidth, page?.implicitWidth ?? 0) + 32
        implicitHeight: tabBar.implicitHeight + (page?.implicitHeight ?? 0) + 16 + 12 + 16
        // Square top edge so it reads as hanging off the bar.
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: 24
        bottomRightRadius: 24
        color: Theme.surface
        border.width: 1
        border.color: Theme.alpha(Theme.outline, 0.2)
        clip: true

        Behavior on y {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }
        Behavior on implicitWidth {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }
        Behavior on implicitHeight {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }

        HoverHandler {
            id: cardHover
        }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: Panels.closeDashboard()
            Keys.onLeftPressed: root.setTab(Panels.dashboardTab - 1)
            Keys.onRightPressed: root.setTab(Panels.dashboardTab + 1)
            Keys.onTabPressed: root.setTab(Panels.dashboardTab + 1)
            Keys.onBacktabPressed: root.setTab(Panels.dashboardTab - 1)
        }

        // Tab bar: icon + label, with an indicator that slides under the active tab.
        Item {
            id: tabBar
            anchors.top: parent.top
            anchors.topMargin: 16
            anchors.horizontalCenter: parent.horizontalCenter
            implicitWidth: tabRow.implicitWidth
            implicitHeight: tabRow.implicitHeight + 6

            WheelHandler {
                onWheel: e => root.setTab(Panels.dashboardTab + (e.angleDelta.y > 0 ? -1 : 1))
            }

            Row {
                id: tabRow
                spacing: 4

                Repeater {
                    model: root.tabs

                    Clickable {
                        id: tab
                        required property var modelData
                        required property int index
                        readonly property bool current: Panels.dashboardTab === index

                        implicitWidth: 168
                        implicitHeight: 40
                        radius: 12
                        onClicked: Panels.dashboardTab = index

                        Row {
                            anchors.centerIn: parent
                            spacing: 8
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                icon: tab.modelData.icon
                                color: tab.current ? Theme.primary : Theme.fgSurfaceVariant
                            }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: tab.modelData.label
                                font.bold: tab.current
                                color: tab.current ? Theme.primary : Theme.fgSurfaceVariant
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                x: Panels.dashboardTab * (168 + tabRow.spacing) + 168 / 2 - width / 2
                width: 64
                height: 3
                radius: 2
                color: Theme.primary
                Behavior on x {
                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                }
            }
        }

        Rectangle {
            id: divider
            anchors.top: tabBar.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            height: 1
            color: Theme.alpha(Theme.outline, 0.2)
        }

        // All pages exist (cheap); only the current one is shown.
        Item {
            id: pages
            anchors.top: divider.bottom
            anchors.topMargin: 12
            anchors.horizontalCenter: parent.horizontalCenter
            width: card.page?.implicitWidth ?? 0
            height: card.page?.implicitHeight ?? 0

            DashTab {
                visible: Panels.dashboardTab === 0
            }
            MediaTab {
                visible: Panels.dashboardTab === 1
            }
            PerformanceTab {
                visible: Panels.dashboardTab === 2
            }
        }
    }
}
