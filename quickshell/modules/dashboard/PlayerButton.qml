import QtQuick
import qs.components
import qs.theme

// Round media control; `filled` is the prominent play/pause style.
Clickable {
    id: root

    property string icon
    property bool filled: false
    property bool checked: false
    property int size: 40

    implicitWidth: size
    implicitHeight: size
    radius: filled && checked ? size * 0.3 : size / 2
    baseColor: filled ? Theme.primary : checked ? Theme.secondaryContainer : Theme.alpha(Theme.fgSurface, 0.06)
    opacity: enabled ? 1 : 0.4

    Behavior on radius {
        NumberAnimation { duration: 200 }
    }

    Icon {
        anchors.centerIn: parent
        icon: root.icon
        size: Math.round(root.size * 0.45)
        color: root.filled ? Theme.fgPrimary : root.checked ? Theme.fgSecondaryContainer : Theme.fgSurface
    }
}
