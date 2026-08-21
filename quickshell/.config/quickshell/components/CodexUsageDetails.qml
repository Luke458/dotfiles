pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../services"
import "."

Item {
    id: root

    implicitWidth: 420
    implicitHeight: mainLayout.implicitHeight + Theme.sectionPadding * 2

    function compactNumber(value) {
        const number = Number(value);
        if (!isFinite(number) || number < 0)
            return "—";
        if (number >= 1000000000)
            return (number / 1000000000).toFixed(1) + "B";
        if (number >= 1000000)
            return (number / 1000000).toFixed(1) + "M";
        if (number >= 1000)
            return (number / 1000).toFixed(1) + "K";
        return Math.round(number).toString();
    }

    function resetText(timestamp) {
        if (!timestamp)
            return "Reset time unavailable";
        const reset = new Date(timestamp);
        const remainingMs = timestamp - Timekeeping.now.getTime();
        if (remainingMs <= 0)
            return "Resetting now";

        const totalMinutes = Math.ceil(remainingMs / 60000);
        const days = Math.floor(totalMinutes / 1440);
        const hours = Math.floor((totalMinutes % 1440) / 60);
        const minutes = totalMinutes % 60;
        let countdown = "";
        if (days > 0)
            countdown = days + "d " + hours + "h";
        else if (hours > 0)
            countdown = hours + "h " + minutes + "m";
        else
            countdown = minutes + "m";
        return "Resets " + Qt.formatDateTime(reset, "ddd h:mm AP") + " · " + countdown;
    }

    function usageColor(remainingPercent) {
        if (remainingPercent <= 20)
            return Theme.negative;
        if (remainingPercent <= 40)
            return Theme.yellow;
        return Theme.selBg;
    }

    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: Theme.sectionPadding
        spacing: Theme.spacingContent

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingComfortable

            Text {
                text: "\u{f121}"
                color: Theme.selBg
                font.family: Theme.fontIcon
                font.pixelSize: Theme.fontSizeDisplayLarge
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingTiny

                Text {
                    text: "CODEX USAGE"
                    color: Theme.selFg
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeHeadingLarge
                    font.bold: true
                }

                Text {
                    text: {
                        const parts = [];
                        if (CodexUsageService.planType)
                            parts.push(CodexUsageService.planType + " plan");
                        if (CodexUsageService.creditsUnlimited)
                            parts.push("unlimited credits");
                        else if (CodexUsageService.hasCredits && CodexUsageService.creditBalance)
                            parts.push(CodexUsageService.creditBalance + " credits");
                        parts.push("local app-server");
                        return parts.join(" · ");
                    }
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
                enabled: !CodexUsageService.loading
                onClicked: CodexUsageService.refresh()

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
                    text: CodexUsageService.loading ? "…" : "\u{f0450}"
                    color: refreshButton.enabled ? Theme.fg : Theme.placeholderFg
                    font.family: CodexUsageService.loading ? Theme.fontMono : Theme.fontIcon
                    font.pixelSize: Theme.fontSizeTitle
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.separator
        }

        ColumnLayout {
            id: usageWindows
            Layout.fillWidth: true
            Layout.preferredHeight: CodexUsageService.windows.length * 58
                + Math.max(0, CodexUsageService.windows.length - 1) * spacing
            spacing: Theme.spacingSection
            visible: CodexUsageService.hasData

            Repeater {
                model: CodexUsageService.windows

                delegate: ColumnLayout {
                    id: windowDelegate
                    required property var modelData

                    Layout.fillWidth: true
                    spacing: Theme.spacingCompact

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: windowDelegate.modelData.label
                            color: Theme.selFg
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLabel
                            font.bold: true
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: windowDelegate.modelData.remainingPercent + "% LEFT"
                            color: root.usageColor(windowDelegate.modelData.remainingPercent)
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLabel
                            font.bold: true
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 9
                        color: Theme.border
                        radius: Theme.radiusMedium
                        opacity: Theme.opacityProminent

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.width * (windowDelegate.modelData.remainingPercent / 100)
                            color: root.usageColor(windowDelegate.modelData.remainingPercent)
                            radius: Theme.radiusMedium

                            Behavior on width {
                                NumberAnimation { duration: 450; easing.type: Easing.OutCubic }
                            }
                        }
                    }

                    Text {
                        text: root.resetText(windowDelegate.modelData.resetsAtMs)
                        color: Theme.fg
                        opacity: Theme.opacityStrong
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeBody
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingComfortable
            visible: !CodexUsageService.hasData

            Text {
                Layout.fillWidth: true
                text: CodexUsageService.loading ? "Connecting to Codex…" : CodexUsageService.errorMessage
                color: CodexUsageService.hasError ? Theme.negative : Theme.fg
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeLabel
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

            Text {
                Layout.fillWidth: true
                text: "Run `codex login` if the account session has expired."
                visible: CodexUsageService.hasError
                color: Theme.fg
                opacity: Theme.opacityStrong
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeBody
                horizontalAlignment: Text.AlignHCenter
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
                text: "TOKEN ACTIVITY"
                color: Theme.selFg
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeLabel
                font.bold: true
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacingXLarge
                Layout.rightMargin: Theme.spacingXLarge
                spacing: Theme.spacingSmall

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    spacing: Theme.spacingTiny
                    Text {
                        Layout.fillWidth: true
                        text: root.compactNumber(CodexUsageService.lifetimeTokens)
                        color: Theme.selFg
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeDisplay
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "LIFETIME"
                        color: Theme.fg
                        opacity: Theme.opacityStrong
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeCaption
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    spacing: Theme.spacingTiny
                    Text {
                        Layout.fillWidth: true
                        text: root.compactNumber(CodexUsageService.peakDailyTokens)
                        color: Theme.selFg
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeDisplay
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "PEAK DAY"
                        color: Theme.fg
                        opacity: Theme.opacityStrong
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeCaption
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    spacing: Theme.spacingTiny
                    Text {
                        Layout.fillWidth: true
                        text: CodexUsageService.longestStreakDays >= 0 ? CodexUsageService.longestStreakDays + "d" : "—"
                        color: Theme.selFg
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeDisplay
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "BEST STREAK"
                        color: Theme.fg
                        opacity: Theme.opacityStrong
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeCaption
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Read-only · credentials stay with Codex"
                color: Theme.fg
                opacity: Theme.opacitySubtle
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeCaption
            }

            Item { Layout.fillWidth: true }

            Text {
                text: CodexUsageService.lastUpdated.getTime() > 0
                    ? (CodexUsageService.stale ? "Stale · " : "Updated ")
                        + Qt.formatTime(CodexUsageService.lastUpdated, "h:mm AP")
                    : "Waiting for update"
                color: CodexUsageService.stale ? Theme.yellow : Theme.fg
                opacity: Theme.opacitySubtle
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeCaption
            }
        }
    }
}
