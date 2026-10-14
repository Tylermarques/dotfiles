import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.components
import qs.theme

RowLayout {
    id: root

    readonly property UPowerDevice dev: UPower.displayDevice

    visible: dev?.isLaptopBattery ?? false
    spacing: 5

    Icon {
        icon: root.dev?.iconName ?? ""
    }

    StyledText {
        text: `${Math.round((root.dev?.percentage ?? 0) * 100)}%`
    }

    Rectangle {
        implicitWidth: 75
        implicitHeight: 20
        radius: 10
        color: Theme.surface

        Rectangle {
            width: parent.width * (root.dev?.percentage ?? 0)
            height: parent.height
            radius: 10
            color: Theme.primary
        }
    }
}
