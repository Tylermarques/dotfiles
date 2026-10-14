import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services
import qs.theme

// Hours over minutes, as in Caelestia's dashboard clock.
ColumnLayout {
    spacing: -10

    StyledText {
        Layout.alignment: Qt.AlignHCenter
        text: Qt.formatDateTime(Time.now, "HH")
        font.pixelSize: 44
        font.bold: true
        color: Theme.fgSurface
    }
    StyledText {
        Layout.alignment: Qt.AlignHCenter
        text: "•••"
        font.pixelSize: 28
        color: Theme.primary
    }
    StyledText {
        Layout.alignment: Qt.AlignHCenter
        text: Qt.formatDateTime(Time.now, "mm")
        font.pixelSize: 44
        font.bold: true
        color: Theme.fgSurface
    }
}
