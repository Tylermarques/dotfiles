import QtQuick
import QtQuick.Layouts
import qs.theme

// Row inside an Expander: icon, label, and a check mark or trailing text.
Clickable {
    id: root

    property string icon
    property string text
    property bool checked: false
    property string trailing: ""

    Layout.fillWidth: true
    implicitHeight: 40
    radius: 16

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 10

        Icon {
            visible: root.icon !== ""
            icon: root.icon
        }
        StyledText {
            Layout.fillWidth: true
            text: root.text
            elide: Text.ElideRight
        }
        StyledText {
            visible: root.trailing !== ""
            text: root.trailing
            color: Theme.fgSurfaceVariant
        }
        Icon {
            visible: root.checked
            icon: "object-select-symbolic"
        }
    }
}
