pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Services.Pipewire
import "../services"

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

            // Master Volume
            Column {
                width: parent.width - 40
                spacing: Theme.spacingSection

                Text {
                    width: parent.width
                    text: "MASTER VOLUME"
                    color: Theme.selFg
                    font.pixelSize: Theme.fontSizeHeadingLarge
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
                                selected: Boolean(Volume.muted)
                                iconText: selected ? "\uf6a9" : "\uf028"
                                Accessible.name: "Master mute"
                                enabled: Volume.audioSink !== null
                                onClicked: Volume.toggleMute()
                            }

                    StyledSlider {
                        id: masterSlider
                        Accessible.name: "Master volume"
                        Layout.fillWidth: true
                        enabled: Volume.audioSink !== null
                        from: 0; to: 1; stepSize: 0.01
                        value: Volume.volume
                        onMoved: Volume.setVolume(value)

                        Binding on value {
                    restoreMode: Binding.RestoreNone
                            value: Volume.volume
                            when: !masterSlider.pressed
                        }
                    }

                    Text {
                        text: Volume.volumePercent + "%"
                        color: Theme.fg; font.pixelSize: Theme.fontSizeBar; font.family: Theme.fontMono; font.bold: true
                        Layout.preferredWidth: 40
                    }
                }
            }

            Text {
                width: parent.width - Theme.sectionPadding * 2
                visible: Volume.sinks.length === 0
                text: "No audio output available"
                color: Theme.fg
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeLabel
                wrapMode: Text.Wrap
            }

            // Applications Section
            Column {
                width: parent.width - 40
                spacing: Theme.spacingLarge
                visible: Volume.apps.length > 0

                Rectangle { width: parent.width; height: 1; color: Theme.border; opacity: Theme.opacityFaint }

                Text {
                    width: parent.width
                    text: "APPLICATIONS"
                    color: Theme.selFg; font.pixelSize: Theme.fontSizeLabel; font.family: Theme.fontMono; font.bold: true; horizontalAlignment: Text.AlignHCenter
                }

                Repeater {
                    model: Volume.apps
                    delegate: Column {
                        id: appDelegate
                        required property var modelData
                        width: parent.width
                        spacing: Theme.spacingComfortable

                        property string appName: Volume.getAppName(appDelegate.modelData)

                        PwObjectTracker { objects: [appDelegate.modelData] }

                        RowLayout {
                            width: parent.width
                            spacing: Theme.spacingSection

                            IconImage {
                                id: appIconImage
                                // Track the failed URL instead of assigning
                                // `source` imperatively, which would destroy
                                // the binding and freeze the icon forever.
                                property string failedSource: ""
                                source: {
                                    const icon = Volume.getAppIcon(appDelegate.modelData);
                                    const resolved = (icon.startsWith("file://") || icon.startsWith("image://"))
                                        ? icon
                                        : "image://icon/" + icon;
                                    return resolved === failedSource ? "image://icon/audio-card" : resolved;
                                }
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                onStatusChanged: if (status === Image.Error) failedSource = source.toString()
                            }

                            Text {
                                text: appDelegate.appName.toUpperCase()
                                color: Theme.fg; font.pixelSize: Theme.fontSizeLabel; font.family: Theme.fontMono; Layout.fillWidth: true; elide: Text.ElideRight
                            }

                            StyledButton {
                                id: appMuteBtn
                                fixedWidth: 32
                                selected: Boolean(appDelegate.modelData && appDelegate.modelData.audio && appDelegate.modelData.audio.muted)
                                iconText: selected ? "\uf6a9" : "\uf028"
                                Accessible.name: appDelegate.appName + " mute"
                                enabled: appDelegate.modelData !== null
                                onClicked: Volume.toggleAppMute(appDelegate.appName)
                            }

                            Text {
                                text: Math.round(((appDelegate.modelData && appDelegate.modelData.audio) ? appDelegate.modelData.audio.volume : 0) * 100) + "%"
                                color: Theme.fg; font.pixelSize: Theme.fontSizeBody; font.family: Theme.fontMono
                            }
                        }

                        StyledSlider {
                            id: appSlider
                            Accessible.name: appDelegate.appName + " volume"
                            width: parent.width
                            from: 0; to: 1; stepSize: 0.01
                            value: (appDelegate.modelData && appDelegate.modelData.audio) ? appDelegate.modelData.audio.volume : 0
                            onMoved: Volume.setAppVolume(appDelegate.appName, value)

                            Binding on value {
                    restoreMode: Binding.RestoreNone
                                value: (appDelegate.modelData && appDelegate.modelData.audio) ? appDelegate.modelData.audio.volume : 0
                                when: !appSlider.pressed
                            }
                        }
                    }
                }
            }

            // Devices Section
            Column {
                width: parent.width - 40
                spacing: Theme.spacingSection

                Rectangle { width: parent.width; height: 1; color: Theme.border; opacity: Theme.opacityFaint }

                Text {
                    width: parent.width
                    text: "OUTPUT DEVICES"
                    color: Theme.selFg; font.pixelSize: Theme.fontSizeLabel; font.family: Theme.fontMono; font.bold: true; horizontalAlignment: Text.AlignHCenter
                }

                Repeater {
                    model: Volume.sinks
                    delegate: Button {
                        id: sinkBtn
                        required property var modelData
                        width: parent.width
                        flat: true
                        onClicked: Volume.selectSink(sinkBtn.modelData)

                        background: Rectangle {
                            implicitHeight: 38; radius: Theme.radiusPanel
                            color: (Volume.audioSink && Volume.audioSink.id === sinkBtn.modelData.id) ? Theme.selectionSubtle : (sinkBtn.hovered ? Theme.hoverSubtle : Theme.transparent)
                            border.width: (Volume.audioSink && Volume.audioSink.id === sinkBtn.modelData.id) ? 1 : 0
                            border.color: Theme.selBg
                        }

                        contentItem: RowLayout {
                            spacing: Theme.spacingSection
                            anchors.fill: parent
                            anchors.leftMargin: Theme.controlPadding
                            anchors.rightMargin: Theme.controlPadding
                            IconImage {
                                source: (Volume.audioSink && Volume.audioSink.id === sinkBtn.modelData.id) ? "image://icon/emblem-ok-symbolic" : "image://icon/audio-speakers"
                                Layout.preferredWidth: 18
                                Layout.preferredHeight: 18
                            }
                            Text {
                                text: Volume.getNodeName(sinkBtn.modelData).toUpperCase()
                                color: (Volume.audioSink && Volume.audioSink.id === sinkBtn.modelData.id) ? Theme.selFg : Theme.fg
                                font.pixelSize: Theme.fontSizeBody; font.family: Theme.fontMono; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true
                            }
                        }
                    }
                }
            }
        }
    }
}
