pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../services"

Item {
    id: root

    Component.onCompleted: Stats.acquireGpuDetails()
    Component.onDestruction: Stats.releaseGpuDetails()

    implicitWidth: 430
    implicitHeight: Math.min(620, layout.implicitHeight + 22)

    function usageColor(value) {
        if (value >= 90) return Theme.critical;
        if (value >= 70) return Theme.yellow;
        return Theme.selBg;
    }

    function percentText(value) {
        return value >= 0 ? value + "%" : "--";
    }

    function tempText(value) {
        return value >= 0 ? value + "°C" : "--";
    }

    function powerText(value) {
        return value >= 0 ? value.toFixed(1) + " W" : "--";
    }

    function clockText(value) {
        if (value < 0) return "--";
        if (value >= 1000) return (value / 1000).toFixed(2) + " GHz";
        return value + " MHz";
    }

    function voltageText(value) {
        if (value < 0) return "--";
        return value >= 1000 ? (value / 1000).toFixed(2) + " V" : value + " mV";
    }

    function bytesText(used, total) {
        if (used < 0 || total <= 0) return "--";
        return Stats.formatBytes(used) + " / " + Stats.formatBytes(total);
    }

    function vramProcessText(bytes, usage) {
        if (bytes <= 0) return "--";
        const percent = Stats.gpuVramTotal > 0 ? " (" + usage.toFixed(1) + "%)" : "";
        return Stats.formatBytes(bytes) + percent;
    }

    function plainText(value) {
        return value && value.length > 0 ? value : "--";
    }

    function getHeaderValue(index) {
        switch (index) {
            case 0: return root.percentText(Stats.gpuUsage);
            case 1: return root.percentText(Stats.gpuVramUsage);
            case 2: return root.tempText(Stats.gpuTempHotspot >= 0 ? Stats.gpuTempHotspot : Stats.gpuTempEdge);
            case 3: return root.powerText(Stats.gpuPower);
            default: return "";
        }
    }

    function getHeaderColor(index) {
        switch (index) {
            case 0: return Theme.selFg;
            case 1: return Stats.gpuVramUsage >= 85 ? Theme.red : Theme.selFg;
            case 2: return (Stats.gpuTempHotspot >= 95 || Stats.gpuTempEdge >= 95) ? Theme.red : Theme.selFg;
            case 3: return Theme.selFg;
            default: return Theme.selFg;
        }
    }

    function getMetricValue(index) {
        switch (index) {
            case 0: return Stats.gpuUsage;
            case 1: return Stats.gpuVramUsage;
            case 2: return Stats.gpuVisVramUsage;
            case 3: return Stats.gpuGttUsage;
            case 4: return Stats.gpuMemUsage;
            case 5: return Stats.gpuVcnUsage;
            default: return 0;
        }
    }

    function getMetricDetail(index) {
        switch (index) {
            case 0: return root.percentText(Stats.gpuUsage);
            case 1: return root.bytesText(Stats.gpuVramUsed, Stats.gpuVramTotal);
            case 2: return root.bytesText(Stats.gpuVisVramUsed, Stats.gpuVisVramTotal);
            case 3: return root.bytesText(Stats.gpuGttUsed, Stats.gpuGttTotal);
            case 4: return root.percentText(Stats.gpuMemUsage);
            case 5: return root.percentText(Stats.gpuVcnUsage);
            default: return "";
        }
    }

    function getMetricVisible(index) {
        switch (index) {
            case 0: return Stats.gpuUsage >= 0;
            case 1: return Stats.gpuVramUsage >= 0;
            case 2: return Stats.gpuVisVramUsage >= 0;
            case 3: return Stats.gpuGttUsage >= 0;
            case 4: return Stats.gpuMemUsage >= 0;
            case 5: return Stats.gpuVcnUsage >= 0;
            default: return false;
        }
    }

    function getThermalValue(index) {
        switch (index) {
            case 0: return root.tempText(Stats.gpuTempEdge);
            case 1: return root.tempText(Stats.gpuTempHotspot);
            case 2: return root.tempText(Stats.gpuTempMem);
            case 3: return root.tempText(Stats.gpuTempVrGfx);
            case 4: return root.tempText(Stats.gpuTempVrMem);
            case 5: return root.tempText(Stats.gpuTempVrSoc);
            default: return "";
        }
    }

    function getThermalHot(index) {
        switch (index) {
            case 0: return Stats.gpuTempEdge >= 85;
            case 1: return Stats.gpuTempHotspot >= 95;
            case 2: return Stats.gpuTempMem >= 90;
            case 3: return Stats.gpuTempVrGfx >= 90;
            case 4: return Stats.gpuTempVrMem >= 90;
            case 5: return Stats.gpuTempVrSoc >= 90;
            default: return false;
        }
    }

    function getThermalVisible(index) {
        switch (index) {
            case 0: return Stats.gpuTempEdge >= 0;
            case 1: return Stats.gpuTempHotspot >= 0;
            case 2: return Stats.gpuTempMem >= 0;
            case 3: return Stats.gpuTempVrGfx >= 0;
            case 4: return Stats.gpuTempVrMem >= 0;
            case 5: return Stats.gpuTempVrSoc >= 0;
            default: return false;
        }
    }

    function getClockValue(index) {
        switch (index) {
            case 0: return root.clockText(Stats.gpuClock);
            case 1: return root.clockText(Stats.gpuMemoryClock);
            case 2: return root.clockText(Stats.gpuSocClock);
            case 3: return root.clockText(Stats.gpuVideoClock);
            case 4: return root.clockText(Stats.gpuVideoClock1);
            case 5: return root.powerText(Stats.gpuPower);
            case 6: return Stats.gpuFanRpm >= 0 ? Stats.gpuFanRpm + " RPM" : "--";
            case 7: return root.voltageText(Stats.gpuVoltage);
            case 8: return root.voltageText(Stats.gpuMemVoltage);
            case 9: return root.voltageText(Stats.gpuSocVoltage);
            default: return "";
        }
    }

    function getClockVisible(index) {
        switch (index) {
            case 0: return Stats.gpuClock >= 0;
            case 1: return Stats.gpuMemoryClock >= 0;
            case 2: return Stats.gpuSocClock >= 0;
            case 3: return Stats.gpuVideoClock >= 0;
            case 4: return Stats.gpuVideoClock1 >= 0;
            case 5: return Stats.gpuPower >= 0;
            case 6: return Stats.gpuFanRpm >= 0;
            case 7: return Stats.gpuVoltage >= 0;
            case 8: return Stats.gpuMemVoltage >= 0;
            case 9: return Stats.gpuSocVoltage >= 0;
            default: return false;
        }
    }

    function getDeviceValue(index) {
        switch (index) {
            case 0: return root.plainText(Stats.gpuPci);
            case 1: return root.plainText(Stats.gpuPcieSpeed) + " x" + root.plainText(Stats.gpuPcieWidth);
            case 2: return root.plainText(Stats.gpuPcieMaxSpeed) + " x" + root.plainText(Stats.gpuPcieMaxWidth);
            case 3: return root.plainText(Stats.gpuVramVendor);
            case 4: return root.plainText(Stats.gpuVbiosVersion);
            case 5: return root.plainText(Stats.gpuThrottleStatus);
            default: return "";
        }
    }

    function getDeviceVisible(index) {
        switch (index) {
            case 0: return Stats.gpuPci.length > 0;
            case 1: return Stats.gpuPcieSpeed.length > 0 || Stats.gpuPcieWidth.length > 0;
            case 2: return Stats.gpuPcieMaxSpeed.length > 0 || Stats.gpuPcieMaxWidth.length > 0;
            case 3: return Stats.gpuVramVendor.length > 0;
            case 4: return Stats.gpuVbiosVersion.length > 0;
            case 5: return Stats.gpuThrottleStatus.length > 0;
            default: return false;
        }
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
                text: Stats.gpuModel || "AMD GPU"
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

                Repeater {
                    model: ["LOAD", "VRAM", "TEMP", "POWER"]

                    delegate: RowLayout {
                        id: headerMetric
                        required property int index
                        required property string modelData
                        spacing: Theme.spacingSection

                        ColumnLayout {
                            Layout.preferredWidth: 84
                            spacing: Theme.spacingXSmall

                            Text {
                                text: headerMetric.modelData
                                color: Theme.fg
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: Theme.fontMono
                                font.bold: true
                                opacity: Theme.opacitySecondaryLow
                                Layout.alignment: Qt.AlignHCenter
                            }

                            Text {
                                text: root.getHeaderValue(headerMetric.index)
                                color: root.getHeaderColor(headerMetric.index)
                                font.pixelSize: Theme.fontSizeDisplay
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
                            visible: headerMetric.index < 3
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.border
                opacity: Theme.opacityVerySubtle
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingMedium

                Repeater {
                    model: ["GPU Load", "VRAM", "Visible VRAM", "GTT", "Memory Busy", "Video Engine"]

                    delegate: ColumnLayout {
                        id: metricDelegate
                        required property int index
                        required property string modelData
                        Layout.fillWidth: true
                        spacing: Theme.spacingCompact
                        visible: root.getMetricVisible(metricDelegate.index)

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: metricDelegate.modelData
                                color: Theme.fg
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeLabel
                                Layout.fillWidth: true
                            }

                            Text {
                                text: root.getMetricDetail(metricDelegate.index)
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
                                width: Math.max(parent.radius * 2, (Math.max(0, root.getMetricValue(metricDelegate.index)) / 100) * parent.width)
                                height: parent.height
                                radius: Theme.radiusCompact
                                color: root.usageColor(root.getMetricValue(metricDelegate.index))

                                Behavior on width {
                                    NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.border
                opacity: Theme.opacityVerySubtle
            }

            Text {
                text: "THERMALS"
                color: Theme.selFg
                font.pixelSize: Theme.fontSizeLabel
                font.family: Theme.fontMono
                font.bold: true
                Layout.fillWidth: true
            }

            GridLayout {
                id: thermalGrid
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 14
                rowSpacing: 8

                Repeater {
                    model: ["Edge", "Hotspot", "Memory", "VR GFX", "VR MEM", "VR SOC"]

                    delegate: RowLayout {
                        id: thermalDelegate
                        required property int index
                        required property string modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: Math.max(130, (thermalGrid.width - thermalGrid.columnSpacing) / 2)
                        visible: root.getThermalVisible(thermalDelegate.index)

                        Text {
                            text: thermalDelegate.modelData
                            color: Theme.fg
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLabel
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Text {
                            text: root.getThermalValue(thermalDelegate.index)
                            color: root.getThermalHot(thermalDelegate.index) ? Theme.red : Theme.selFg
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLabel
                            font.bold: true
                        }
                    }
                }
            }

            Text {
                text: "CLOCKS / POWER"
                color: Theme.selFg
                font.pixelSize: Theme.fontSizeLabel
                font.family: Theme.fontMono
                font.bold: true
                Layout.fillWidth: true
            }

            GridLayout {
                id: clockGrid
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 14
                rowSpacing: 8

                Repeater {
                    model: ["GFX Clock", "VRAM Clock", "SoC Clock", "Video Clock", "Video Clock 1", "Power", "Fan", "VDDGFX", "VMEM", "VSOC"]

                    delegate: RowLayout {
                        id: clockDelegate
                        required property int index
                        required property string modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: Math.max(130, (clockGrid.width - clockGrid.columnSpacing) / 2)
                        visible: root.getClockVisible(clockDelegate.index)

                        Text {
                            text: clockDelegate.modelData
                            color: Theme.fg
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLabel
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Text {
                            text: root.getClockValue(clockDelegate.index)
                            color: Theme.selFg
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLabel
                            font.bold: true
                        }
                    }
                }
            }

            Text {
                text: "VRAM PROCESSES"
                color: Theme.selFg
                font.pixelSize: Theme.fontSizeLabel
                font.family: Theme.fontMono
                font.bold: true
                Layout.fillWidth: true
                visible: Stats.gpuAvailable
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingComfortable
                visible: Stats.gpuAvailable

                Repeater {
                    model: Stats.gpuVramProcessesModel

                    delegate: ColumnLayout {
                        id: processDelegate
                        required property real bytes
                        required property int index
                        required property string name
                        required property real usage
                        Layout.fillWidth: true
                        spacing: Theme.spacingCompact

                        RowLayout {
                            Layout.fillWidth: true

                            Text {
                                text: processDelegate.name
                                color: Theme.fg
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeLabel
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Text {
                                text: root.vramProcessText(processDelegate.bytes, processDelegate.usage)
                                color: Theme.selFg
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeLabel
                                font.bold: true
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 6
                            color: Theme.border
                            radius: Theme.radiusCompact
                            opacity: Theme.opacityMuted

                            Rectangle {
                                width: Math.max(parent.radius * 2, Math.min(parent.width, (Math.max(0, processDelegate.usage) / 100) * parent.width))
                                height: parent.height
                                radius: Theme.radiusCompact
                                color: root.usageColor(processDelegate.usage)

                                Behavior on width {
                                    NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: Theme.border
                            opacity: Theme.opacityBarelyVisible
                            visible: processDelegate.index < Stats.gpuVramProcessesModel.count - 1
                        }
                    }
                }

                Text {
                    text: "NO PROCESS VRAM DATA"
                    color: Theme.fg
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeBody
                    opacity: Theme.opacitySecondary
                    visible: Stats.gpuVramProcessesModel.count === 0
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            Text {
                text: "DEVICE"
                color: Theme.selFg
                font.pixelSize: Theme.fontSizeLabel
                font.family: Theme.fontMono
                font.bold: true
                Layout.fillWidth: true
            }

            GridLayout {
                id: deviceGrid
                Layout.fillWidth: true
                columns: 1
                rowSpacing: 8

                Repeater {
                    model: ["PCI", "PCIe", "Max PCIe", "VRAM Vendor", "VBIOS", "Throttle"]

                    delegate: RowLayout {
                        id: deviceDelegate
                        required property int index
                        required property string modelData
                        Layout.fillWidth: true
                        visible: root.getDeviceVisible(deviceDelegate.index)

                        Text {
                            text: deviceDelegate.modelData
                            color: Theme.fg
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLabel
                            Layout.preferredWidth: 100
                        }

                        Text {
                            text: root.getDeviceValue(deviceDelegate.index)
                            color: Theme.selFg
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLabel
                            font.bold: true
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }
                }
            }

            Text {
                text: "NO GPU DATA"
                color: Theme.fg
                font.family: Theme.fontMono
                visible: !Stats.gpuAvailable
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: Stats.gpuMetricsAvailable ? "AMDGPU_TOP METRICS / SYSFS MEMORY" : "SYSFS METRICS"
                color: Theme.fg
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSmall
                opacity: Theme.opacityMedium
                Layout.alignment: Qt.AlignHCenter
                visible: Stats.gpuAvailable
            }

            Item { Layout.preferredHeight: 4 }
        }
    }
}
