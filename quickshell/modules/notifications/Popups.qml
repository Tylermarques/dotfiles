import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services
import qs.theme

// Notification popups, top-right of every screen. Only the cards take input.
PanelWindow {
    id: root

    required property ShellScreen modelData

    screen: modelData
    visible: Notifs.popups.count > 0
    anchors {
        top: true
        right: true
    }
    implicitWidth: 464 + 32
    implicitHeight: Math.max(1, list.contentHeight + 32)
    color: "transparent"
    // Sit below the bar (respect its zone) without reserving space ourselves.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.namespace: "quickshell:notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    mask: Region { item: list.contentItem }

    ListView {
        id: list
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        interactive: false
        model: Notifs.popups

        add: Transition {
            NumberAnimation { property: "x"; from: 480; duration: 250; easing.type: Easing.OutCubic }
        }
        remove: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: 200 }
        }
        displaced: Transition {
            NumberAnimation { property: "y"; duration: 250; easing.type: Easing.OutCubic }
        }

        delegate: NotificationCard {
            id: card

            required property int nid

            width: ListView.view.width
            entry: null
            notif: Notifs.get(nid)
            cardColor: Theme.surface
            border.width: 1
            border.color: Theme.alpha(Theme.outline, 0.25)
            onCloseClicked: Notifs.dismiss(nid)

            // Popup timeout (sender's expireTimeout if set); paused while hovered.
            Timer {
                running: !hover.hovered && card.notif?.urgency !== 2  // critical stays
                interval: (card.notif?.expireTimeout ?? 0) > 0 ? card.notif.expireTimeout
                    : Config.notifications.popupTimeoutMs
                onTriggered: Notifs.hidePopup(card.nid)
            }

            HoverHandler { id: hover }
        }
    }
}
