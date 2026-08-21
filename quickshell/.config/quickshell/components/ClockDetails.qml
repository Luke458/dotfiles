pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../services"
import "."

Item {
    id: root

    implicitWidth: 380
    implicitHeight: mainLayout.implicitHeight + Theme.sectionPadding * 2

    component ClockButton: Button {
        id: control
        flat: true
        padding: Theme.spacingComfortable

        background: Rectangle {
            implicitHeight: 34
            radius: Theme.radiusMedium
            color: control.checked ? Theme.selectionMedium : (control.hovered ? Theme.hover : Theme.surfaceSubtle)
            border.width: 1
            border.color: control.checked ? Theme.selBg : Theme.border
        }

        contentItem: Text {
            text: control.text
            color: control.hovered || control.checked ? Theme.selFg : Theme.fg
            font.pixelSize: Theme.fontSizeBody
            font.family: Theme.fontMono
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: Theme.sectionPadding
        spacing: Theme.spacingLarge

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSmall

            Text {
                Layout.fillWidth: true
                text: Timekeeping.fullTime
                color: Theme.selFg
                font.pixelSize: Theme.fontSizeHero
                font.family: Theme.fontMono
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                Layout.fillWidth: true
                text: Timekeeping.fullDate
                color: Theme.fg
                font.pixelSize: Theme.fontSizeBar
                font.family: Theme.fontMono
                horizontalAlignment: Text.AlignHCenter
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Theme.spacingComfortable

                ClockButton {
                    text: "12 HOUR"
                    checked: !Timekeeping.use24Hour
                    onClicked: Timekeeping.use24Hour = false
                }

                ClockButton {
                    text: "24 HOUR"
                    checked: Timekeeping.use24Hour
                    onClicked: Timekeeping.use24Hour = true
                }

                ClockButton {
                    text: "BAR SECONDS"
                    checked: Timekeeping.showSecondsInBar
                    onClicked: Timekeeping.showSecondsInBar = !Timekeeping.showSecondsInBar
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.separator
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingComfortable

            Text {
                text: "STOPWATCH"
                color: Theme.selFg
                font.pixelSize: Theme.fontSizeLabel
                font.family: Theme.fontMono
                font.bold: true
            }

            Text {
                Layout.fillWidth: true
                text: Timekeeping.stopwatchText
                color: Theme.selFg
                font.pixelSize: Theme.fontSizeValueMedium
                font.family: Theme.fontMono
                horizontalAlignment: Text.AlignHCenter
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Theme.spacingComfortable

                ClockButton {
                    text: Timekeeping.stopwatchRunning ? "PAUSE" : "START"
                    onClicked: Timekeeping.toggleStopwatch()
                }

                ClockButton {
                    text: "RESET"
                    onClicked: Timekeeping.resetStopwatch()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.separator
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingComfortable

            Text {
                text: "COUNTDOWN"
                color: Theme.selFg
                font.pixelSize: Theme.fontSizeLabel
                font.family: Theme.fontMono
                font.bold: true
            }

            Text {
                Layout.fillWidth: true
                text: Timekeeping.countdownText
                color: Timekeeping.countdownRemainingMs <= 0 ? Theme.red : Theme.selFg
                font.pixelSize: Theme.fontSizeValueMedium
                font.family: Theme.fontMono
                horizontalAlignment: Text.AlignHCenter
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Theme.spacingComfortable

                ClockButton {
                    text: "-1 MIN"
                    enabled: !Timekeeping.countdownRunning
                    onClicked: Timekeeping.adjustCountdown(-1)
                }

                ClockButton {
                    text: Timekeeping.countdownRunning ? "PAUSE" : "START"
                    onClicked: Timekeeping.toggleCountdown()
                }

                ClockButton {
                    text: "+1 MIN"
                    enabled: !Timekeeping.countdownRunning
                    onClicked: Timekeeping.adjustCountdown(1)
                }

                ClockButton {
                    text: "RESET"
                    onClicked: Timekeeping.resetCountdown()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.separator
        }

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "SYSTEM UPTIME"
                color: Theme.selFg
                font.pixelSize: Theme.fontSizeLabel
                font.family: Theme.fontMono
                font.bold: true
            }

            Item { Layout.fillWidth: true }

            Text {
                text: Timekeeping.uptimeText
                color: Theme.selFg
                font.pixelSize: Theme.fontSizeBody
                font.family: Theme.fontMono
            }
        }
    }
}
