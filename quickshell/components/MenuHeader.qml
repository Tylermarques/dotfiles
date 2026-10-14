import QtQuick
import QtQuick.Layouts
import qs.theme

// Expander heading: icon + title, optional on/off switch on the right.
RowLayout {
    id: root

    property string icon
    property string text
    property bool showSwitch: false
    property bool checked: false
    signal toggled(bool value)

    Layout.fillWidth: true
    Layout.bottomMargin: 8
    spacing: 12

    Icon {
        visible: root.icon !== ""
        icon: root.icon
        size: 26
    }
    StyledText {
        Layout.fillWidth: true
        text: root.text
        font.pixelSize: 20
    }
    Switch {
        visible: root.showSwitch
        checked: root.checked
        onToggled: v => root.toggled(v)
    }
}
