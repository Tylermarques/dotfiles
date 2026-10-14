import QtQuick
import QtQuick.Layouts
import qs.components
import qs.theme

// Card heading: tinted icon tile, title and an optional subtitle.
RowLayout {
    id: root

    property string icon
    property string title
    property string subtitle
    property color accent: Theme.primary

    spacing: 12

    Rectangle {
        implicitWidth: 40
        implicitHeight: 40
        radius: 12
        color: Theme.alpha(root.accent, 0.16)
        Icon {
            anchors.centerIn: parent
            icon: root.icon
            size: 20
            color: root.accent
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        StyledText {
            text: root.title
            font.pixelSize: 17
            font.bold: true
        }
        StyledText {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.subtitle
            font.pixelSize: 12
            color: Theme.fgSurfaceVariant
            elide: Text.ElideRight
        }
    }
}
