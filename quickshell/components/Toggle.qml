import QtQuick
import QtQuick.Layouts
import qs.theme

// Quick-settings button: icon + label, primary when active, optional menu arrow.
Clickable {
    id: root

    property string icon
    property string text
    property bool active: false
    property bool hasMenu: false
    property bool menuOpen: false

    readonly property color fg: active ? Theme.surface : Theme.fgSurface

    Layout.fillWidth: true
    implicitHeight: 42
    radius: 21
    baseColor: active ? Theme.primary : Theme.surfaceContainerHigh

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 12
        spacing: 8

        Icon {
            icon: root.icon
            color: root.fg
        }
        StyledText {
            Layout.fillWidth: true
            text: root.text
            color: root.fg
            elide: Text.ElideRight
        }
        Icon {
            visible: root.hasMenu
            icon: "pan-down-symbolic"
            size: 20
            color: root.fg
            rotation: root.menuOpen ? 180 : 0
            Behavior on rotation { NumberAnimation { duration: 200 } }
        }
    }
}
