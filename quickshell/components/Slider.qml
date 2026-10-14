import QtQuick
import qs.theme

// Material-style slider. `value` is 0..1 and follows its binding until dragged;
// moved(v) fires while the user drags or clicks.
Item {
    id: root

    property real value: 0
    property color trackColor: Theme.secondaryContainer
    property color fillColor: Theme.primary
    property real trackHeight: 16
    readonly property bool pressed: mouse.pressed

    signal moved(real value)

    implicitHeight: Math.max(trackHeight, 24)
    opacity: enabled ? 1 : 0.5

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: root.trackHeight
        radius: height / 2
        color: root.trackColor

        Rectangle {
            width: Math.max(height, parent.width * Math.min(1, Math.max(0, root.value)))
            height: parent.height
            radius: height / 2
            color: root.fillColor
            visible: root.value > 0
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function update(x: real): void {
            root.moved(Math.min(1, Math.max(0, x / width)));
        }
        onPressed: m => update(m.x)
        onPositionChanged: m => { if (pressed) update(m.x); }
        onWheel: w => root.moved(Math.min(1, Math.max(0, root.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
