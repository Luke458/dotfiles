pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../services"

// Recording flyout: start/stop the screen and webcam recorders, choose audio
// sources for screen capture, and see where files land.
Item {
    id: root

    implicitWidth: 420
    implicitHeight: Math.min(620, contentColumn.height + 40)

    readonly property string screenStatus: {
        const tick = Timekeeping.now.getTime();
        if (!RecordingService.screenActive) return "Idle";
        return "Recording · " + RecordingService.formatElapsed(RecordingService.elapsedSec(RecordingService.screenStartedAt));
    }

    readonly property string webcamStatus: {
        const tick = Timekeeping.now.getTime();
        if (!RecordingService.webcamActive) return "Idle";
        return "Recording · " + RecordingService.formatElapsed(RecordingService.elapsedSec(RecordingService.webcamStartedAt));
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.spacingWide
            padding: Theme.sectionPadding

            Text {
                width: parent.width - 40
                text: "RECORDING"
                color: Theme.selFg
                font.pixelSize: Theme.panelTitleSize
                font.family: Theme.fontMono
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
            }

            // ---------- Screen ----------
            Column {
                width: parent.width - 40
                spacing: Theme.spacingSection

                Rectangle { width: parent.width; height: 1; color: Theme.border; opacity: Theme.opacityFaint }

                Text {
                    width: parent.width
                    text: "SCREEN"
                    color: Theme.selFg
                    font.pixelSize: Theme.panelBodySize
                    font.family: Theme.fontMono
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingSection

                    Text {
                        text: "\uf111"
                        color: RecordingService.screenActive ? Theme.negative : Theme.fg
                        font.family: Theme.fontIcon
                        font.pixelSize: Theme.fontSizeBar
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.screenStatus
                        color: RecordingService.screenActive ? Theme.negative : Theme.fg
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.panelBodySize
                        font.bold: RecordingService.screenActive
                    }

                    StyledButton {
                        text: RecordingService.screenActive ? "Stop" : "Start"
                        bordered: true
                        selected: RecordingService.screenActive
                        tint: RecordingService.screenActive ? Theme.negative : "transparent"
                        enabled: !RecordingService.busy
                        onClicked: RecordingService.toggleScreen()
                    }
                }

                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingSection

                    Text {
                        Layout.fillWidth: true
                        text: "Desktop audio"
                        color: Theme.fg
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.panelBodySize
                    }

                    StyledSwitch {
                        checked: RecordingService.desktopAudio
                        enabled: !RecordingService.screenActive
                        Accessible.name: "Record desktop audio"
                        onToggled: RecordingService.desktopAudio = !checked
                    }
                }

                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingSection

                    Text {
                        Layout.fillWidth: true
                        text: "Microphone"
                        color: Theme.fg
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.panelBodySize
                    }

                    StyledSwitch {
                        checked: RecordingService.micAudio
                        enabled: !RecordingService.screenActive
                        Accessible.name: "Record microphone"
                        onToggled: RecordingService.micAudio = !checked
                    }
                }

                Text {
                    width: parent.width
                    visible: RecordingService.screenOutputPath !== "" || RecordingService.screenActive
                    text: RecordingService.screenActive || RecordingService.screenOutputPath !== ""
                        ? "→ " + RecordingService.screenOutputPath : ""
                    color: Theme.fg
                    opacity: Theme.opacitySecondary
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.panelCaptionSize
                    elide: Text.ElideMiddle
                    wrapMode: Text.Wrap
                }
            }

            // ---------- Webcam ----------
            Column {
                width: parent.width - 40
                spacing: Theme.spacingSection

                Rectangle { width: parent.width; height: 1; color: Theme.border; opacity: Theme.opacityFaint }

                Text {
                    width: parent.width
                    text: "WEBCAM"
                    color: Theme.selFg
                    font.pixelSize: Theme.panelBodySize
                    font.family: Theme.fontMono
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingSection

                    Text {
                        text: "\uf111"
                        color: RecordingService.webcamActive ? Theme.negative : Theme.fg
                        font.family: Theme.fontIcon
                        font.pixelSize: Theme.fontSizeBar
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.webcamStatus
                        color: RecordingService.webcamActive ? Theme.negative : Theme.fg
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.panelBodySize
                        font.bold: RecordingService.webcamActive
                    }

                    StyledButton {
                        text: RecordingService.webcamActive ? "Stop" : "Start"
                        bordered: true
                        selected: RecordingService.webcamActive
                        tint: RecordingService.webcamActive ? Theme.negative : "transparent"
                        enabled: !RecordingService.busy
                        onClicked: RecordingService.toggleWebcam()
                    }
                }

                Text {
                    width: parent.width
                    visible: RecordingService.webcamOutputPath !== "" || RecordingService.webcamActive
                    text: RecordingService.webcamActive || RecordingService.webcamOutputPath !== ""
                        ? "→ " + RecordingService.webcamOutputPath : ""
                    color: Theme.fg
                    opacity: Theme.opacitySecondary
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.panelCaptionSize
                    elide: Text.ElideMiddle
                    wrapMode: Text.Wrap
                }

                Text {
                    width: parent.width
                    text: "Device: " + RecordingService.webcamDevice.split("/").pop()
                    color: Theme.fg
                    opacity: Theme.opacitySecondary
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.panelCaptionSize
                    elide: Text.ElideMiddle
                }
            }

            Text {
                width: parent.width - 40
                visible: RecordingService.errorMessage !== ""
                text: RecordingService.errorMessage
                color: Theme.negative
                font.family: Theme.fontMono
                font.pixelSize: Theme.panelCaptionSize
                wrapMode: Text.Wrap
            }

            Text {
                width: parent.width - 40
                visible: RecordingService.lastSaved !== ""
                text: "Saved: " + RecordingService.lastSaved
                color: Theme.fg
                opacity: Theme.opacitySecondary
                font.family: Theme.fontMono
                font.pixelSize: Theme.panelCaptionSize
                elide: Text.ElideMiddle
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
