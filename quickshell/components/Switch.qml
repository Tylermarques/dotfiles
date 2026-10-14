import QtQuick
import qs.theme

// On/off switch. Emits toggled(); the owner updates `checked` from its source.
Rectangle {
    id: root

    property bool checked: false
    signal toggled(bool value)

    implicitWidth: 48
    implicitHeight: 26
    radius: height / 2
    color: checked ? Theme.primary : Theme.surfaceContainerHighest
    border.width: checked ? 0 : 2
    border.color: Theme.outline

    Behavior on color { ColorAnimation { duration: 150 } }

    Rectangle {
        width: root.checked ? 18 : 14
        height: width
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? root.width - width - 4 : 6
        color: root.checked ? Theme.fgPrimary : Theme.outline

        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
