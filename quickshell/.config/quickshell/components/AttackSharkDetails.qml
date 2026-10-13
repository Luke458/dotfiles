pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../services"
import "."

Item {
    id: root

    implicitWidth: 380
    implicitHeight: mainLayout.implicitHeight + Theme.sectionPadding * 2

    Component.onCompleted: AttackSharkMetrics.beginDetails()
    Component.onDestruction: AttackSharkMetrics.endDetails()

    function linkText() {
        const parts = [];
        if (AttackSharkMetrics.connected && AttackSharkMetrics.mode === "wired")
            parts.push("USB-C cable");
        else if (AttackSharkMetrics.connected)
            parts.push("2.4 GHz receiver");
        else
            parts.push(AttackSharkMetrics.hasError ? "Mouse unavailable" : "Receiver not found");
        if (AttackSharkMetrics.wired && AttackSharkMetrics.mode !== "wired")
            parts.push("USB-C connected");
        if (AttackSharkMetrics.charging)
            parts.push("charging");
        return parts.join(" · ");
    }

    function batteryColor() {
        if (!AttackSharkMetrics.hasBattery)
            return Theme.fg;
        if (AttackSharkMetrics.battery <= 15)
            return Theme.negative;
        if (AttackSharkMetrics.battery <= 30 || AttackSharkMetrics.stale)
            return Theme.yellow;
        return Theme.selBg;
    }

    function ageText() {
        const updated = AttackSharkMetrics.lastUpdated.getTime();
        if (updated <= 0)
            return AttackSharkMetrics.loading ? "Waiting for helper…" : "No battery report received yet";
        const minutes = Math.max(0, Math.floor((Timekeeping.now.getTime() - updated) / 60000));
        let age = "just now";
        if (minutes >= 60)
            age = Math.floor(minutes / 60) + "h " + (minutes % 60) + "m ago";
        else if (minutes >= 1)
            age = minutes + "m ago";
        return (AttackSharkMetrics.stale ? "Stale · last report " : "Reported ") + age;
    }

    function dpiStatusText() {
        if (AttackSharkMetrics.dpiLoading)
            return AttackSharkMetrics.hasDpi ? "Talking to mouse…" : "Reading DPI stages…";
        if (AttackSharkMetrics.dpiError)
            return AttackSharkMetrics.dpiError;
        if (AttackSharkMetrics.hasDpi)
            return "Stage " + AttackSharkMetrics.dpiActiveStage + " · " + AttackSharkMetrics.activeDpi + " DPI"
                + (AttackSharkMetrics.dpiMode ? " · via " + AttackSharkMetrics.dpiMode : "");
        return "";
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
                text: "\u{efba}"
                color: Theme.selBg
                font.family: Theme.fontIcon
                font.pixelSize: Theme.fontSizeDisplayLarge
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingTiny

                Text {
                    text: "ATTACK SHARK R5"
                    color: Theme.selFg
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.panelTitleSize
                    font.bold: true
                }

                Text {
                    Layout.fillWidth: true
                    text: root.linkText()
                    color: AttackSharkMetrics.connected || AttackSharkMetrics.wired ? Theme.fg : Theme.negative
                    opacity: Theme.opacitySecondary
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.panelCaptionSize
                    elide: Text.ElideRight
                }
            }
        }

        Divider { Layout.fillWidth: true }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingCompact

            RowLayout {
                Layout.fillWidth: true

                SectionHeading { text: "BATTERY" }

                Item { Layout.fillWidth: true }

                Text {
                    text: (AttackSharkMetrics.charging ? "\u{f0e7} " : "")
                        + (AttackSharkMetrics.hasBattery ? AttackSharkMetrics.battery + "%" : "--")
                    color: root.batteryColor()
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.panelValueSize
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
                    width: parent.width * (AttackSharkMetrics.hasBattery ? Math.max(0, Math.min(1, AttackSharkMetrics.battery / 100)) : 0)
                    color: root.batteryColor()
                    radius: Theme.radiusMedium

                    Behavior on width {
                        NumberAnimation { duration: 450; easing.type: Easing.OutCubic }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.ageText()
                color: AttackSharkMetrics.stale ? Theme.yellow : Theme.fg
                opacity: Theme.opacitySecondary
                font.family: Theme.fontMono
                font.pixelSize: Theme.panelCaptionSize
            }

            Text {
                Layout.fillWidth: true
                visible: AttackSharkMetrics.hasError
                text: AttackSharkMetrics.errorMessage
                color: Theme.negative
                font.family: Theme.fontMono
                font.pixelSize: Theme.panelCaptionSize
                wrapMode: Text.Wrap
            }
        }

        Divider { Layout.fillWidth: true }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingCompact

            RowLayout {
                Layout.fillWidth: true

                SectionHeading { text: "DPI STAGES" }

                Item { Layout.fillWidth: true }

                StyledButton {
                    iconText: "\u{f0450}"
                    Accessible.name: "Refresh mouse DPI"
                    enabled: !AttackSharkMetrics.dpiLoading
                    onClicked: AttackSharkMetrics.refreshDpi()
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 4
                rowSpacing: Theme.spacingSmall
                columnSpacing: Theme.spacingSmall
                visible: AttackSharkMetrics.hasDpi

                Repeater {
                    model: AttackSharkMetrics.dpiStages

                    delegate: StyledButton {
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        text: modelData
                        Accessible.name: "DPI stage " + (index + 1) + ", " + modelData + " DPI"
                        bordered: true
                        selected: index + 1 === AttackSharkMetrics.dpiActiveStage
                        enabled: AttackSharkMetrics.connected && !AttackSharkMetrics.dpiLoading
                        opacity: enabled ? 1 : Theme.opacityDisabled
                        onClicked: AttackSharkMetrics.selectDpiStage(index + 1)
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.dpiStatusText()
                color: AttackSharkMetrics.dpiError && !AttackSharkMetrics.dpiLoading ? Theme.negative : Theme.fg
                opacity: Theme.opacitySecondary
                font.family: Theme.fontMono
                font.pixelSize: Theme.panelCaptionSize
                wrapMode: Text.Wrap
            }

            RowLayout {
                Layout.fillWidth: true
                visible: AttackSharkMetrics.hasDpi
                spacing: Theme.spacingSmall

                StyledTextField {
                    id: dpiInput
                    Layout.fillWidth: true
                    placeholderText: "Stage " + AttackSharkMetrics.dpiActiveStage + " DPI"
                    enabled: AttackSharkMetrics.connected && !AttackSharkMetrics.dpiLoading
                    validator: IntValidator { bottom: 50; top: 30000 }
                    inputMethodHints: Qt.ImhDigitsOnly
                    onAccepted: {
                        if (applyDpi.enabled)
                            applyDpi.clicked();
                    }
                }

                StyledButton {
                    id: applyDpi
                    text: "Set DPI"
                    enabled: dpiInput.enabled && dpiInput.acceptableInput && Number(dpiInput.text) % 50 === 0
                    onClicked: {
                        AttackSharkMetrics.setDpi(AttackSharkMetrics.dpiActiveStage, Number(dpiInput.text));
                        dpiInput.clear();
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: "Click a stage to switch · set 50–30000 DPI in steps of 50\nBattery reported on change"
            color: Theme.fg
            opacity: Theme.opacitySecondary
            font.family: Theme.fontMono
            font.pixelSize: Theme.panelCaptionSize
            wrapMode: Text.Wrap
        }
    }
}
