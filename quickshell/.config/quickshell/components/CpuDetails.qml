pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../services"

Item {
    id: root

    Component.onCompleted: Stats.acquireCpuDetails()
    Component.onDestruction: Stats.releaseCpuDetails()

    implicitWidth: 430
    implicitHeight: Math.min(560, layout.implicitHeight + 22)

    function usageColor(value) {
        if (value >= 90) return Theme.critical;
        if (value >= 70) return Theme.yellow;
        return Theme.selBg;
    }

    function powerText() {
        return Stats.cpuPower >= 0 ? Stats.cpuPower.toFixed(1) + " W" : "--";
    }

    function clockText(mhz) {
        if (mhz < 0) return "--";
        if (mhz >= 1000) return (mhz / 1000).toFixed(2) + " GHz";
        return mhz + " MHz";
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            id: layout
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Theme.spacingLarge
            spacing: Theme.spacingPanel

            Text {
                text: Stats.cpuModel || "CPU"
                color: Theme.selFg
                font.pixelSize: Theme.fontSizeHeading
                font.family: Theme.fontMono
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 10
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Theme.spacingSection

                ColumnLayout {
                    Layout.preferredWidth: 78
                    spacing: Theme.spacingXSmall

                    Text {
                        text: "TOTAL"
                        color: Theme.fg
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontMono
                        font.bold: true
                        opacity: Theme.opacitySecondaryLow
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: Stats.cpuUsage + "%"
                        color: Theme.selFg
                        font.pixelSize: Theme.fontSizeDisplayLarge
                        font.family: Theme.fontMono
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 42
                    color: Theme.border
                    opacity: Theme.opacityQuarter
                }

                ColumnLayout {
                    Layout.preferredWidth: 94
                    spacing: Theme.spacingXSmall

                    Text {
                        text: "CLOCK"
                        color: Theme.fg
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontMono
                        font.bold: true
                        opacity: Theme.opacitySecondaryLow
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: root.clockText(Stats.cpuClock)
                        color: Theme.selFg
                        font.pixelSize: Theme.fontSizeDisplayLarge
                        font.family: Theme.fontMono
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 42
                    color: Theme.border
                    opacity: Theme.opacityQuarter
                }

                ColumnLayout {
                    Layout.preferredWidth: 78
                    spacing: Theme.spacingXSmall

                    Text {
                        text: "TEMP"
                        color: Theme.fg
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontMono
                        font.bold: true
                        opacity: Theme.opacitySecondaryLow
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: Stats.cpuTemp >= 0 ? Stats.cpuTemp + "°C" : "--"
                        color: Stats.cpuTemp >= 85 ? Theme.red : Theme.selFg
                        font.pixelSize: Theme.fontSizeDisplayLarge
                        font.family: Theme.fontMono
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 42
                    color: Theme.border
                    opacity: Theme.opacityQuarter
                }

                ColumnLayout {
                    Layout.preferredWidth: 88
                    spacing: Theme.spacingXSmall

                    Text {
                        text: "POWER"
                        color: Theme.fg
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontMono
                        font.bold: true
                        opacity: Theme.opacitySecondaryLow
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: root.powerText()
                        color: Theme.selFg
                        font.pixelSize: Theme.fontSizeDisplayLarge
                        font.family: Theme.fontMono
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.border
                opacity: Theme.opacityVerySubtle
            }

            GridLayout {
                id: coreGrid
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 12
                rowSpacing: 12

                Repeater {
                    model: Stats.cpuCores

                    delegate: ColumnLayout {
                        id: coreDelegate
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: Math.max(120, (coreGrid.width - coreGrid.columnSpacing) / 2)
                        spacing: Theme.spacingCompact

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: coreDelegate.modelData.name + (coreDelegate.modelData.clock >= 0 ? "  " + root.clockText(coreDelegate.modelData.clock) : "")
                                color: Theme.fg
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeLabel
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Text {
                                text: coreDelegate.modelData.usage + "%"
                                color: Theme.selFg
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeLabel
                                font.bold: true
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 7
                            color: Theme.border
                            radius: Theme.radiusCompact
                            opacity: Theme.opacityMuted

                            Rectangle {
                                width: Math.max(parent.radius * 2, (coreDelegate.modelData.usage / 100) * parent.width)
                                height: parent.height
                                radius: Theme.radiusCompact
                                color: root.usageColor(coreDelegate.modelData.usage)

                                Behavior on width {
                                    NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
                                }
                            }
                        }
                    }
                }
            }

            Text {
                text: "COLLECTING DATA..."
                color: Theme.fg
                font.family: Theme.fontMono
                visible: Stats.cpuCores.length === 0
                Layout.alignment: Qt.AlignHCenter
            }

            Item { Layout.preferredHeight: 4 }
        }
    }
}
