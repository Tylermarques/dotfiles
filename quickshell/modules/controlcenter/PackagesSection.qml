import QtQuick
import QtQuick.Layouts
import qs.components
import qs.config
import qs.services
import qs.theme

// Parcels in flight (services/Packages.qml). One row per package: status icon,
// description, status · carrier, latest event, ETA. Click a row for its event
// history and actions. Hidden when there is nothing to show.
Card {
    id: root

    property bool showAll: false
    property string expandedId: ""
    readonly property int maxRows: Config.packages.maxRows
    readonly property var shown: showAll ? Packages.packages : Packages.packages.slice(0, maxRows)

    Layout.fillWidth: true
    implicitHeight: column.implicitHeight + 24
    visible: Packages.count > 0
    color: Theme.surfaceContainerLow

    ColumnLayout {
        id: column
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.bottomMargin: 2
            spacing: 8

            Icon {
                icon: "package-x-generic-symbolic"
                size: 18
            }
            StyledText {
                Layout.fillWidth: true
                text: "Packages"
                font.pixelSize: 16
            }
            StyledText {
                text: Packages.count
                color: Theme.fgSurfaceVariant
                font.pixelSize: 13
            }
            Clickable {
                id: refresh
                implicitWidth: 28
                implicitHeight: 28
                radius: 14
                onClicked: Packages.scanNow()
                Icon {
                    anchors.centerIn: parent
                    icon: "view-refresh-symbolic"
                    size: 16
                    color: Theme.fgSurfaceVariant
                    RotationAnimation on rotation {
                        running: Packages.busy
                        from: 0
                        to: 360
                        duration: 1000
                        loops: Animation.Infinite
                        onRunningChanged: if (!running) parent.rotation = 0
                    }
                }
                Tooltip {
                    target: refresh
                    shown: refresh.hovered
                    text: Packages.generatedAt ? `Updated ${Packages.formatTime(Packages.generatedAt)} · scan mail now` : "Scan mail now"
                }
            }
        }

        Repeater {
            model: root.shown

            PackageRow {
                required property var modelData
                Layout.fillWidth: true
                pkg: modelData
                expanded: root.expandedId === modelData.id
                onToggled: root.expandedId = expanded ? "" : modelData.id
            }
        }

        Clickable {
            Layout.fillWidth: true
            implicitHeight: 28
            visible: Packages.count > root.maxRows
            onClicked: root.showAll = !root.showAll
            StyledText {
                anchors.centerIn: parent
                text: root.showAll ? "Show fewer" : `Show ${Packages.count - root.maxRows} more`
                color: Theme.fgSurfaceVariant
                font.pixelSize: 13
            }
        }
    }

    component PackageRow: Clickable {
        id: row

        required property var pkg
        property bool expanded: false
        readonly property var info: Packages.statusInfo(pkg.status)
        readonly property var latest: pkg.latest_event
        readonly property bool isFinal: pkg.status === "delivered" || pkg.status === "returned"
        readonly property string when: isFinal ? Packages.formatDay(pkg.delivered_at || latest?.time || "")
            : pkg.eta ? Packages.formatDay(pkg.eta) : ""

        signal toggled

        implicitHeight: body.implicitHeight + 16
        radius: 14
        baseColor: expanded ? Theme.surfaceContainerHigh : "transparent"
        onClicked: toggled()

        Behavior on implicitHeight {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            id: body
            x: 8
            y: 8
            width: parent.width - 16
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.alignment: Qt.AlignTop
                    implicitWidth: 36
                    implicitHeight: 36
                    radius: 18
                    color: Theme.alpha(row.info.color, 0.16)
                    Icon {
                        anchors.centerIn: parent
                        icon: row.info.icon
                        size: 18
                        color: row.info.color
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        StyledText {
                            Layout.fillWidth: true
                            text: row.pkg.description
                            elide: Text.ElideRight
                            font.pixelSize: 14
                        }
                        StyledText {
                            visible: row.when !== ""
                            text: row.isFinal ? row.when : `ETA ${row.when}`
                            color: row.isFinal ? Theme.fgSurfaceVariant : Theme.fgSurface
                            font.pixelSize: 12
                        }
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: `${Packages.statusLabel(row.pkg)} · ${row.pkg.carrier_name}`
                        color: row.info.color
                        elide: Text.ElideRight
                        font.pixelSize: 12
                    }
                    StyledText {
                        Layout.fillWidth: true
                        visible: text !== ""
                        text: row.latest ? [row.latest.text, row.latest.location, Packages.formatTime(row.latest.time)].filter(s => s).join(" · ") : ""
                        color: Theme.fgSurfaceVariant
                        elide: Text.ElideRight
                        font.pixelSize: 12
                    }
                }
            }

            // Expanded: event history + actions.
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 46
                visible: row.expanded
                spacing: 6

                Repeater {
                    model: row.expanded ? row.pkg.events : []

                    RowLayout {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.alignment: Qt.AlignTop
                            Layout.topMargin: 5
                            implicitWidth: 8
                            implicitHeight: 8
                            radius: 4
                            color: index === 0 ? Packages.statusInfo(modelData.status).color : Theme.alpha(Theme.outline, 0.6)
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            StyledText {
                                Layout.fillWidth: true
                                text: modelData.text
                                wrapMode: Text.Wrap
                                font.pixelSize: 12
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: [Packages.formatTime(modelData.time), modelData.location, modelData.source === "email" ? "from email" : modelData.source === "inferred" ? "presumed" : ""].filter(s => s).join(" · ")
                                color: Theme.fgSurfaceVariant
                                elide: Text.ElideRight
                                font.pixelSize: 11
                            }
                        }
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: row.pkg.events.length === 0
                    text: row.pkg.carrier_state === "supported" ? "No tracking events yet"
                        : `No ${row.pkg.carrier_name} tracking module yet. One is being added automatically.`
                    wrapMode: Text.Wrap
                    color: Theme.fgSurfaceVariant
                    font.pixelSize: 12
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: !!row.pkg.last_error
                    text: `Last check failed: ${row.pkg.last_error}`
                    wrapMode: Text.Wrap
                    color: Theme.error
                    font.pixelSize: 11
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    spacing: 6

                    StyledText {
                        Layout.fillWidth: true
                        text: row.pkg.tracking_number
                        color: Theme.fgSurfaceVariant
                        elide: Text.ElideMiddle
                        font.pixelSize: 11
                    }
                    ActionButton {
                        icon: "web-browser-symbolic"
                        label: "Track"
                        enabled: !!row.pkg.tracking_url
                        onClicked: Packages.openTracking(row.pkg)
                    }
                    ActionButton {
                        icon: "edit-delete-symbolic"
                        label: "Remove"
                        onClicked: Packages.dismiss(row.pkg)
                    }
                }
            }
        }
    }

    component ActionButton: Clickable {
        id: button
        property string icon
        property string label
        implicitWidth: content.implicitWidth + 20
        implicitHeight: 28
        radius: 14
        baseColor: Theme.surfaceContainerHighest
        opacity: enabled ? 1 : 0.5

        RowLayout {
            id: content
            anchors.centerIn: parent
            spacing: 6
            Icon {
                icon: button.icon
                size: 14
            }
            StyledText {
                text: button.label
                font.pixelSize: 12
            }
        }
    }
}
