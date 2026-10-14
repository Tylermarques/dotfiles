import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import qs.services
import qs.theme

// One notification. `entry` is a history snapshot; `notif` is the live object
// (null once the sender has closed it, then there are no actions).
Rectangle {
    id: root

    property var entry
    property Notification notif: entry ? Notifs.liveFor(entry) : null
    property color cardColor: Theme.surfaceContainerHigh

    readonly property string appName: notif?.appName ?? entry?.appName ?? ""
    readonly property string summary: notif?.summary ?? entry?.summary ?? ""
    readonly property string body: notif?.body ?? entry?.body ?? ""
    readonly property string image: notif?.image || entry?.image || ""
    readonly property string appIcon: notif?.appIcon || entry?.appIcon || ""
    readonly property bool screenshot: appName === "grimblast"

    signal closeClicked

    implicitHeight: layout.implicitHeight + 32
    radius: 16
    color: cardColor

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // Normal: icon, summary/body, close.  Screenshot: preview + close.
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Image {
                visible: root.screenshot
                Layout.preferredWidth: 1920 / 7
                Layout.preferredHeight: 1080 / 7
                source: root.screenshot ? Qt.resolvedUrl(root.appIcon || root.image) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 1920 / 7
                layer.enabled: true
                layer.smooth: true
            }

            Icon {
                visible: !root.screenshot
                Layout.alignment: Qt.AlignTop
                icon: root.image || root.appIcon || "dialog-information-symbolic"
                size: 48
                recolor: false
            }

            ColumnLayout {
                visible: !root.screenshot
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.summary
                    font.bold: true
                    elide: Text.ElideRight
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.body
                    color: Theme.fgSurfaceVariant
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    onLinkActivated: link => Qt.openUrlExternally(link)
                }
            }

            Item {
                visible: root.screenshot
                Layout.fillWidth: true
            }

            Clickable {
                Layout.alignment: Qt.AlignTop
                implicitWidth: 28
                implicitHeight: 28
                radius: 14
                onClicked: root.closeClicked()

                Icon {
                    anchors.centerIn: parent
                    icon: "window-close-symbolic"
                    size: 20
                }
            }
        }

        StyledText {
            visible: root.screenshot
            text: "Screenshot saved"
            font.pixelSize: 17
        }

        RowLayout {
            readonly property var buttons: root.screenshot
                ? [{ text: "Open", run: () => Quickshell.execDetached(["xdg-open", root.appIcon || root.image]) },
                   { text: "Close", run: () => root.closeClicked() }]
                : (root.notif?.actions ?? []).map(a => ({ text: a.text, run: () => a.invoke() }))

            visible: buttons.length > 0
            Layout.fillWidth: true
            spacing: 10

            Repeater {
                model: parent.buttons

                Clickable {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 32
                    radius: 8
                    baseColor: Theme.alpha(Theme.fgSurface, 0.05)
                    onClicked: modelData.run()

                    StyledText {
                        anchors.centerIn: parent
                        text: parent.modelData.text
                        color: Theme.primary
                    }
                }
            }
        }
    }
}
