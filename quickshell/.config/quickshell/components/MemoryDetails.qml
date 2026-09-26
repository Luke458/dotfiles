pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../services"

Item {
    id: root

    Component.onCompleted: Stats.acquireMemoryDetails()
    Component.onDestruction: Stats.releaseMemoryDetails()
    
    implicitWidth: 350
    implicitHeight: Math.min(500, layout.implicitHeight + 40)

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            id: layout
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Theme.spacingLarge
            spacing: Theme.spacingLarge

            Text {
                text: "MEMORY · " + Stats.memUsage + "% USED"
                color: Theme.selFg
                font.pixelSize: Theme.fontSizeHeading
                font.family: Theme.fontMono
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 10
            }

            Repeater {
                model: Stats.memHogsModel
                delegate: ColumnLayout {
                    id: memoryHog
                    required property int index
                    required property string name
                    required property real rss
                    required property real usage
                    Layout.fillWidth: true
                    spacing: Theme.spacingCompact

                    RowLayout {
                        Layout.fillWidth: true
                        
                        Text { 
                            text: memoryHog.name
                            color: Theme.fg
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeBar
                            Layout.fillWidth: true 
                            elide: Text.ElideRight
                        }
                        
                        Text { 
                            text: Stats.formatBytes(memoryHog.rss * 1024) + " (" + memoryHog.usage.toFixed(1) + "%)"
                            color: Theme.selFg
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeLabel
                            font.bold: true
                        }
                    }

                    // Usage Bar
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 6
                        color: Theme.border
                        radius: Theme.radiusCompact

                        
                        Rectangle {
                            // Show the same percentage as the adjacent label.
                            width: Math.max(0, Math.min(1, memoryHog.usage / 100)) * parent.width
                            height: parent.height
                            radius: Theme.radiusCompact
                            color: memoryHog.usage > 5 ? Theme.critical : Theme.selBg
                            
                            Behavior on width {
                                NumberAnimation { duration: 500; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                    
                    // Separator
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Theme.border
                        opacity: Theme.opacityBarelyVisible
                        visible: memoryHog.index < (Stats.memHogsModel.count - 1)
                    }
                }
            }
            
            // Empty State
            Text {
                text: "COLLECTING DATA..."
                color: Theme.fg
                font.family: Theme.fontMono
                visible: Stats.memHogsModel.count === 0
                Layout.alignment: Qt.AlignHCenter
            }
            
            Item { Layout.preferredHeight: 15 }
        }
    }
}
