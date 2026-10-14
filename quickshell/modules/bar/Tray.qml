import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import qs.components

RowLayout {
    id: root

    spacing: 10

    Repeater {
        model: SystemTray.items.values

        Clickable {
            id: item

            required property SystemTrayItem modelData

            implicitWidth: 28
            implicitHeight: 28
            radius: 6
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton && !modelData.onlyMenu) modelData.activate();
                else if (mouse.button === Qt.MiddleButton) modelData.secondaryActivate();
                else if (modelData.hasMenu) menu.open();
            }

            Icon {
                anchors.centerIn: parent
                icon: item.modelData.icon
                size: 24
                recolor: false
            }

            QsMenuAnchor {
                id: menu
                menu: item.modelData.menu
                anchor.item: item
                anchor.edges: Edges.Bottom
                anchor.gravity: Edges.Bottom
            }
        }
    }
}
