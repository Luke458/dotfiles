pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../services"
import "."

Item {
    id: root

    implicitWidth: 380
    implicitHeight: mainLayout.implicitHeight + Theme.sectionPadding * 2

    component ClockButton: StyledButton {
        selected: checked
        bordered: true
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

        Divider { Layout.fillWidth: true }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingComfortable

            SectionHeading {
                text: "STOPWATCH"
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

        Divider { Layout.fillWidth: true }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingComfortable

            SectionHeading {
                text: "COUNTDOWN"
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

        Divider { Layout.fillWidth: true }

        RowLayout {
            Layout.fillWidth: true

            SectionHeading {
                text: "SYSTEM UPTIME"
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
