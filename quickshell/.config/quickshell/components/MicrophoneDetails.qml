pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import "../services"

// Input flyout: adjust the default microphone's volume and choose which source
// is default. Mirrors VolumeMixerDetails for the capture side.
Item {
    id: root

    implicitWidth: 400
    implicitHeight: Math.min(600, contentColumn.height + 40)

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        Column {
            id: contentColumn
            width: parent.width
            spacing: Theme.spacingWide
            padding: Theme.sectionPadding

            // Master input volume
            Column {
                width: parent.width - 40
                spacing: Theme.spacingSection

                Text {
                    width: parent.width
                    text: "INPUT VOLUME"
                    color: Theme.selFg
                    font.pixelSize: Theme.panelTitleSize
                    font.family: Theme.fontMono
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingLarge

                    StyledButton {
                        id: muteBtn
                        fixedWidth: 32
                        selected: Boolean(Volume.micMuted)
                        iconText: selected ? "\uf131" : "\uf130"
                        Accessible.name: "Microphone mute"
                        enabled: Volume.audioSource !== null
                        onClicked: Volume.toggleMicMute()
                    }

                    StyledSlider {
                        id: micSlider
                        Accessible.name: "Microphone volume"
                        Layout.fillWidth: true
                        enabled: Volume.audioSource !== null
                        from: 0; to: 1; stepSize: 0.01
                        value: Volume.micVolume
                        onMoved: Volume.setMicVolume(value)

                        Binding on value {
                            restoreMode: Binding.RestoreNone
                            value: Volume.micVolume
                            when: !micSlider.pressed
                        }
                    }

                    Text {
                        text: Volume.micPercent + "%"
                        color: Theme.fg
                        font.pixelSize: Theme.panelBodySize
                        font.family: Theme.fontMono
                        font.bold: true
                        Layout.preferredWidth: 40
                    }
                }
            }

            Text {
                width: parent.width - Theme.sectionPadding * 2
                visible: Volume.sources.length === 0
                text: "No audio input available"
                color: Theme.fg
                font.family: Theme.fontMono
                font.pixelSize: Theme.panelBodySize
                wrapMode: Text.Wrap
            }

            // Input devices
            Column {
                width: parent.width - 40
                spacing: Theme.spacingSection
                visible: Volume.sources.length > 0

                Rectangle { width: parent.width; height: 1; color: Theme.border; opacity: Theme.opacityFaint }

                Text {
                    width: parent.width
                    text: "INPUT DEVICES"
                    color: Theme.selFg
                    font.pixelSize: Theme.panelBodySize
                    font.family: Theme.fontMono
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Repeater {
                    model: Volume.sources

                    delegate: Button {
                        id: sourceBtn
                        required property var modelData
                        width: parent.width
                        flat: true
                        onClicked: Volume.selectSource(sourceBtn.modelData)

                        background: Rectangle {
                            implicitHeight: 38
                            radius: Theme.radiusPanel
                            color: (Volume.audioSource && Volume.audioSource.id === sourceBtn.modelData.id)
                                ? Theme.selectionSubtle
                                : (sourceBtn.hovered ? Theme.hoverSubtle : Theme.transparent)
                            border.width: (Volume.audioSource && Volume.audioSource.id === sourceBtn.modelData.id) ? 1 : 0
                            border.color: Theme.selBg
                        }

                        contentItem: RowLayout {
                            spacing: Theme.spacingSection
                            anchors.fill: parent
                            anchors.leftMargin: Theme.controlPadding
                            anchors.rightMargin: Theme.controlPadding

                            IconImage {
                                source: (Volume.audioSource && Volume.audioSource.id === sourceBtn.modelData.id)
                                    ? "image://icon/emblem-ok-symbolic"
                                    : "image://icon/audio-input-microphone"
                                Layout.preferredWidth: 18
                                Layout.preferredHeight: 18
                            }

                            Text {
                                text: Volume.getNodeName(sourceBtn.modelData).toUpperCase()
                                color: (Volume.audioSource && Volume.audioSource.id === sourceBtn.modelData.id) ? Theme.selFg : Theme.fg
                                font.pixelSize: Theme.panelCaptionSize
                                font.family: Theme.fontMono
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }
    }
}
