pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import QtQuick.Controls
import QtQuick.Layouts
import "../services"

Item {
    id: root
    
    implicitWidth: 350
    implicitHeight: Math.min(600, layout.implicitHeight + 40)

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            id: layout
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Theme.spacingLarge
            spacing: Theme.spacingXLarge

            Text {
                text: "Disk Usage"
                color: Theme.selFg
                font.pixelSize: Theme.fontSizeHeading
                font.family: Theme.fontMono
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 10
            }

            Repeater {
                model: Stats.drives
                delegate: ColumnLayout {
                    id: driveDelegate
                    required property int index
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Theme.spacingSection

                    // Drive Header
                    RowLayout {
                        Layout.fillWidth: true
                        
                        IconImage {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            source: driveDelegate.modelData.removable ? "image://icon/drive-removable-media" : "image://icon/drive-harddisk"
                        }

                        Text {
                            text: driveDelegate.modelData.name.toUpperCase() + " (" + driveDelegate.modelData.size + ")"
                            color: Theme.selFg
                            font.family: Theme.fontMono
                            font.bold: true
                            Layout.fillWidth: true
                        }
                    }

                    // Partitions
                    Repeater {
                        model: driveDelegate.modelData.partitions
                        delegate: ColumnLayout {
                            id: partitionDelegate
                            required property int index
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.leftMargin: 24
                            spacing: Theme.spacingCompact

                            RowLayout {
                                Layout.fillWidth: true
                                Text { 
                                    text: partitionDelegate.modelData.mount
                                    color: Theme.fg
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeLabel
                                    Layout.fillWidth: true 
                                }
                                Text { 
                                    text: partitionDelegate.modelData.used + " / " + partitionDelegate.modelData.size + " (" + partitionDelegate.modelData.percent + "%)"
                                    color: Theme.fg
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeBody
                                }
                            }

                            // Usage Bar Container
                            Rectangle {
                                id: barBg
                                Layout.fillWidth: true
                                implicitHeight: 8
                                color: Theme.border
                                radius: Theme.radiusMedium
                                opacity: Theme.opacityMuted
                                
                                // Progress Indicator
                                Rectangle {
                                    id: progressBar
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: Math.max(radius * 2, (partitionDelegate.modelData.percent / 100) * parent.width)
                                    radius: Theme.radiusMedium
                                    color: partitionDelegate.modelData.percent > 90 ? Theme.critical : Theme.selBg
                                    
                                    // Smoothly animate width changes
                                    Behavior on width {
                                        NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
                                    }
                                }
                            }
                            
                            // Separator between partitions
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 1
                                color: Theme.border
                                opacity: Theme.opacityBarelyVisible
                                visible: partitionDelegate.index < (driveDelegate.modelData.partitions ? driveDelegate.modelData.partitions.length - 1 : 0)
                            }
                        }
                    }
                    
                    // Separator between drives
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Theme.border
                        opacity: Theme.opacityFaint
                        Layout.topMargin: 5
                        Layout.bottomMargin: 5
                        visible: driveDelegate.index < (Stats.drives ? Stats.drives.length - 1 : 0)
                    }
                }
            }
            
            // Empty State
            Text {
                text: "NO DRIVES DETECTED"
                color: Theme.fg
                font.family: Theme.fontMono
                visible: Stats.drives.length === 0
                Layout.alignment: Qt.AlignHCenter
            }
            
            Item { Layout.preferredHeight: 15 }
        }
    }
}
