import QtQuick
import qs.theme

// Rounded background that lightens on hover; children go inside.
Rectangle {
    id: root

    property color baseColor: "transparent"
    property alias hovered: mouse.containsMouse
    property alias acceptedButtons: mouse.acceptedButtons
    signal clicked(var mouse)
    signal scrolled(var wheel)

    color: mouse.containsMouse && baseColor.a > 0 ? Theme.hover(baseColor)
        : mouse.containsMouse ? Theme.alpha(Theme.fgSurface, 0.1)
        : baseColor
    radius: Theme.radius

    Behavior on color {
        ColorAnimation { duration: 200 }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: m => root.clicked(m)
        onWheel: w => root.scrolled(w)
    }
}
