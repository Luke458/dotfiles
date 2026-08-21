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
                    font.pixelSize: Theme.fontSizeTitle
                    font.family: Theme.fontMono
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }
                
                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingLarge
                    
                    Button {
                        id: muteBtn
                        flat: true
                        onClicked: Volume.toggleMute()
                        background: Rectangle {
                            implicitWidth: 36; implicitHeight: 36; radius: Theme.radiusPanel
                            color: muteBtn.hovered ? Theme.hover : Theme.transparent
                        }
                        contentItem: IconImage {
                            source: (Volume.audioSink && Volume.audioSink.audio && Volume.audioSink.audio.muted) ? "image://icon/audio-volume-muted" : "image://icon/audio-volume-high"
                            width: 22; height: 22
                        }
                    }
                    
                    Slider {
                        id: masterSlider
                        Layout.fillWidth: true
                        from: 0; to: 1
                        value: Volume.volume
                        onMoved: Volume.setVolume(value)
                        
                        background: Rectangle {
                            x: masterSlider.leftPadding
                            y: masterSlider.topPadding + masterSlider.availableHeight / 2 - height / 2
                            implicitWidth: 200; implicitHeight: 4; width: masterSlider.availableWidth
                            radius: Theme.radiusSmall; color: Theme.border; opacity: Theme.opacitySoft
                            Rectangle { width: masterSlider.visualPosition * parent.width; height: parent.height; color: Theme.selBg; radius: Theme.radiusSmall }
                        }
                        handle: Rectangle {
                            x: masterSlider.leftPadding + masterSlider.visualPosition * (masterSlider.availableWidth - width)
                            y: masterSlider.topPadding + masterSlider.availableHeight / 2 - height / 2
                            implicitWidth: 16; implicitHeight: 16; radius: Theme.radiusLarge; color: Theme.selFg
                        }

                        Binding on value {
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
                                onStatusChanged: if (status === Image.Error) failedSource = Volume.getAppIcon(appDelegate.modelData)
                            }
                            
                            Text {
                                text: appDelegate.appName.toUpperCase()
                                color: Theme.fg; font.pixelSize: Theme.fontSizeLabel; font.family: Theme.fontMono; Layout.fillWidth: true; elide: Text.ElideRight
                            }
                            
                            Button {
                                id: appMuteBtn
                                flat: true
                                onClicked: Volume.toggleAppMute(appDelegate.appName)
                                background: Rectangle {
                                    implicitWidth: 28; implicitHeight: 28; radius: Theme.radiusMedium
                                    color: appMuteBtn.hovered ? Theme.hover : Theme.transparent
                                }
                                contentItem: IconImage {
                                    source: (appDelegate.modelData && appDelegate.modelData.audio && appDelegate.modelData.audio.muted) ? "image://icon/audio-volume-muted" : "image://icon/audio-volume-high"
                                    width: 16; height: 16
                                }
                            }

                            Text {
                                text: Math.round(((appDelegate.modelData && appDelegate.modelData.audio) ? appDelegate.modelData.audio.volume : 0) * 100) + "%"
                                color: Theme.fg; font.pixelSize: Theme.fontSizeBody; font.family: Theme.fontMono
                            }
                        }
                        
                        Slider {
                            id: appSlider
                            width: parent.width
                            from: 0; to: 1
                            value: (appDelegate.modelData && appDelegate.modelData.audio) ? appDelegate.modelData.audio.volume : 0
                            onMoved: Volume.setAppVolume(appDelegate.appName, value)
                            
                            background: Rectangle {
                                x: appSlider.leftPadding; y: appSlider.topPadding + appSlider.availableHeight / 2 - height / 2
                                implicitWidth: 200; implicitHeight: 3; width: appSlider.availableWidth; radius: Theme.radiusSmall; color: Theme.border; opacity: Theme.opacityFaint
                                Rectangle { width: appSlider.visualPosition * parent.width; height: parent.height; color: Theme.selBg; radius: Theme.radiusSmall }
                            }
                            handle: Rectangle {
                                x: appSlider.leftPadding + appSlider.visualPosition * (appSlider.availableWidth - width)
                                y: appSlider.topPadding + appSlider.availableHeight / 2 - height / 2
                                implicitWidth: 12; implicitHeight: 12; radius: Theme.radiusPanel; color: Theme.selFg
                            }

                            Binding on value {
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
