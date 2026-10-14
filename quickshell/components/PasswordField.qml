import QtQuick
import QtQuick.Layouts
import qs.theme

// Inline password entry; Enter submits, Esc clears.
Rectangle {
    id: root

    signal accepted(string text)

    Layout.fillWidth: true
    implicitHeight: 36
    radius: 12
    color: Theme.surfaceContainerHighest
    border.width: input.activeFocus ? 2 : 1
    border.color: input.activeFocus ? Theme.primary : Theme.alpha(Theme.outline, 0.5)

    onVisibleChanged: if (visible) input.forceActiveFocus(); else input.text = ""

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        verticalAlignment: TextInput.AlignVCenter
        echoMode: TextInput.Password
        color: Theme.fgSurface
        font.family: Theme.fontFamily
        font.pixelSize: 14
        clip: true
        onAccepted: if (text) root.accepted(text)
        Keys.onEscapePressed: text = ""

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            visible: !input.text
            text: "Password"
            color: Theme.fgSurfaceVariant
            font.pixelSize: 14
        }
    }
}
