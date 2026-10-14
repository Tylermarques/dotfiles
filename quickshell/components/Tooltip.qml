import QtQuick
import Quickshell
import qs.theme

// Hover tooltip shown below `target` after a short delay while `shown` is true.
PopupWindow {
    id: root

    required property Item target
    property bool shown: false
    property string text: ""

    anchor.item: target
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.margins.top: 6
    implicitWidth: label.implicitWidth + 20
    implicitHeight: label.implicitHeight + 12
    color: "transparent"
    visible: delay.ready && shown && text !== ""

    onShownChanged: shown ? delay.restart() : (delay.stop(), delay.ready = false)

    Timer {
        id: delay
        property bool ready: false
        interval: 500
        onTriggered: ready = true
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: Theme.surfaceContainerHigh

        StyledText {
            id: label
            anchors.centerIn: parent
            text: root.text
            font.pixelSize: 13
        }
    }
}
