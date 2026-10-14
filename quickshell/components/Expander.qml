import QtQuick
import QtQuick.Layouts
import qs.theme

// Collapsible menu box (the control center's drop-down menus).
Item {
    id: root

    property bool open: false
    default property alias content: column.data

    Layout.fillWidth: true
    implicitHeight: open ? box.implicitHeight + 12 : 0
    clip: true
    visible: implicitHeight > 0

    Behavior on implicitHeight {
        NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    Rectangle {
        id: box
        y: 12
        width: parent.width
        implicitHeight: column.implicitHeight + 32
        radius: 16
        color: Theme.surfaceContainerHigh

        ColumnLayout {
            id: column
            anchors.fill: parent
            anchors.margins: 16
            spacing: 2
        }
    }
}
