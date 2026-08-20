pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../services" as Services
import "."

Item {
    id: root

    implicitWidth: 540
    implicitHeight: Math.min(620, contentColumn.implicitHeight)

    Component.onCompleted: Services.PodmanQuadlets.beginDetails()
    Component.onDestruction: Services.PodmanQuadlets.endDetails()

    function statusColor(unit) {
        if (!unit.healthy)
            return Theme.negative;
        if (unit.activeState === "activating")
            return Theme.yellow;
        return Theme.positive;
    }

    function stateText(unit) {
        if (unit.type === "container" && unit.containerState)
            return unit.containerState.toUpperCase();
        return (unit.activeState + " · " + unit.subState).toUpperCase();
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        Column {
            id: contentColumn
            width: parent.width
            padding: Theme.panelPadding
            spacing: Theme.spacingContent

            RowLayout {
                width: parent.width - Theme.panelPadding * 2
                spacing: Theme.spacingSection

                Text {
                    text: "\u{e842}"
                    color: Services.PodmanQuadlets.failed > 0 ? Theme.negative : Theme.selBg
                    font.family: Theme.fontIcon
                    font.pixelSize: Theme.fontSizeValueSmall
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingTiny

                    Text {
                        text: "PODMAN QUADLETS"
                        color: Theme.selFg
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeHeadingLarge
                        font.bold: true
                    }

                    Text {
                        text: Services.PodmanQuadlets.hasData
                            ? Services.PodmanQuadlets.healthy + " of " + Services.PodmanQuadlets.total + " generated units healthy"
                            : "Waiting for user-systemd and Podman"
                        color: Theme.fg
                        opacity: Theme.opacityStrong
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeBody
                    }
                }

                MouseArea {
                    id: refreshButton
                    implicitWidth: refreshIcon.implicitWidth + Theme.controlPadding
                    implicitHeight: 28
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !Services.PodmanQuadlets.loading
                    onClicked: Services.PodmanQuadlets.refresh(true)

                    Rectangle {
                        anchors.fill: parent
                        color: refreshButton.containsMouse ? Theme.hover : Theme.transparent
                        border.color: Theme.border
                        border.width: 1
                        radius: Theme.radiusMedium
                    }

                    Text {
                        id: refreshIcon
                        anchors.centerIn: parent
                        text: Services.PodmanQuadlets.loading ? "…" : "\u{f0450}"
                        color: refreshButton.enabled ? Theme.fg : Theme.placeholderFg
                        font.family: Services.PodmanQuadlets.loading ? Theme.fontMono : Theme.fontIcon
                        font.pixelSize: Theme.fontSizeTitle
                    }
                }
            }

            Rectangle {
                width: parent.width - Theme.panelPadding * 2
                height: 1
                color: Theme.separator
            }

            RowLayout {
                width: parent.width - Theme.panelPadding * 2
                spacing: Theme.spacingComfortable

                Repeater {
                    model: [
                        { value: Services.PodmanQuadlets.runningContainers + "/" + Services.PodmanQuadlets.containers, label: "CONTAINERS" },
                        { value: Services.PodmanQuadlets.detailed ? Services.PodmanQuadlets.totalCpu.toFixed(1) + "%" : "—", label: "CPU" },
                        { value: Services.PodmanQuadlets.detailed ? Services.PodmanQuadlets.totalMemory : "—", label: "MEMORY" }
                    ]

                    delegate: Rectangle {
                        id: summaryCard
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: 56
                        color: Theme.surfaceSubtle
                        border.color: Theme.border
                        border.width: 1
                        radius: Theme.radiusMedium

                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.spacingTiny

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: summaryCard.modelData.value
                                color: Theme.selFg
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeDisplaySmall
                                font.bold: true
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: summaryCard.modelData.label
                                color: Theme.fg
                                opacity: Theme.opacityStrong
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeCaption
                            }
                        }
                    }
                }
            }

            Text {
                width: parent.width - Theme.panelPadding * 2
                visible: Services.PodmanQuadlets.errorMessage.length > 0
                text: Services.PodmanQuadlets.errorMessage
                color: Theme.negative
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeBody
                wrapMode: Text.Wrap
            }

            Column {
                width: parent.width - Theme.panelPadding * 2
                spacing: Theme.spacingComfortable

                Repeater {
                    model: Services.PodmanQuadlets.units

                    delegate: Rectangle {
                        id: unitRow
                        required property var modelData
                        width: parent.width
                        height: 58
                        color: Theme.surfaceSubtle
                        border.color: Theme.border
                        border.width: 1
                        radius: Theme.radiusMedium

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.spacingSection
                            anchors.rightMargin: Theme.spacingSection
                            spacing: Theme.spacingComfortable

                            Rectangle {
                                Layout.preferredWidth: 8
                                Layout.preferredHeight: 8
                                radius: Theme.radiusRound
                                color: root.statusColor(unitRow.modelData)
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacingTiny

                                Text {
                                    Layout.fillWidth: true
                                    text: unitRow.modelData.name
                                    color: Theme.selFg
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeLabel
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: unitRow.modelData.type.toUpperCase() + " · "
                                        + (unitRow.modelData.status || unitRow.modelData.subState)
                                        + (unitRow.modelData.image ? " · " + unitRow.modelData.image : "")
                                    color: Theme.fg
                                    opacity: Theme.opacityStrong
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeSmall
                                    elide: Text.ElideRight
                                }
                            }

                            ColumnLayout {
                                Layout.preferredWidth: 72
                                spacing: Theme.spacingTiny

                                Text {
                                    Layout.fillWidth: true
                                    text: unitRow.modelData.cpu || "—"
                                    color: Theme.selFg
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeLabel
                                    horizontalAlignment: Text.AlignRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: "CPU"
                                    color: Theme.fg
                                    opacity: Theme.opacityStrong
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeCaption
                                    horizontalAlignment: Text.AlignRight
                                }
                            }

                            ColumnLayout {
                                Layout.preferredWidth: 76
                                spacing: Theme.spacingTiny

                                Text {
                                    Layout.fillWidth: true
                                    text: unitRow.modelData.memory || "—"
                                    color: Theme.selFg
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeLabel
                                    horizontalAlignment: Text.AlignRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: "MEMORY"
                                    color: Theme.fg
                                    opacity: Theme.opacityStrong
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeCaption
                                    horizontalAlignment: Text.AlignRight
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: stateLabel.implicitWidth + Theme.spacingSection
                                Layout.preferredHeight: 24
                                color: Theme.withAlpha(root.statusColor(unitRow.modelData), Theme.opacityVerySubtle)
                                border.color: root.statusColor(unitRow.modelData)
                                border.width: 1
                                radius: Theme.radiusMedium

                                Text {
                                    id: stateLabel
                                    anchors.centerIn: parent
                                    text: root.stateText(unitRow.modelData)
                                    color: root.statusColor(unitRow.modelData)
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeCaption
                                    font.bold: true
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                width: parent.width - Theme.panelPadding * 2

                Text {
                    text: "Read-only · user quadlets"
                    color: Theme.fg
                    opacity: Theme.opacitySubtle
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeCaption
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: Services.PodmanQuadlets.lastUpdated.getTime() > 0
                        ? "Updated " + Qt.formatTime(Services.PodmanQuadlets.lastUpdated, "hh:mm:ss")
                        : "Not updated"
                    color: Theme.fg
                    opacity: Theme.opacitySubtle
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeCaption
                }
            }
        }
    }
}
