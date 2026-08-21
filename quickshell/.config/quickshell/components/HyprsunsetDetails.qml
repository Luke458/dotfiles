import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "." as Components

Item {
    id: root
    required property var hyprsunset

    implicitWidth: 250
    implicitHeight: layout.implicitHeight + 40
    
    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Theme.sectionPadding
        spacing: Theme.spacingXLarge
        
        RowLayout {
            Layout.fillWidth: true
            
            Text {
                text: "HYPRSUNSET"
                color: Theme.selFg
                font.pixelSize: Theme.fontSizeTitle
                font.family: Theme.fontMono
                font.bold: true
                Layout.fillWidth: true
            }
            
            Components.StyledSwitch {
                id: enabledSwitch
                checked: root.hyprsunset.enabled
                onToggled: root.hyprsunset.setEnabled(!checked)
            }
        }
        
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.border
            opacity: Theme.opacitySoft
        }
        
        // Temperature Slider
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSmall
            enabled: root.hyprsunset.enabled
            opacity: enabled ? 1.0 : 0.4
            
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Temperature"
                    color: Theme.fg
                    font.pixelSize: Theme.fontSizeLabel
                    font.family: Theme.fontMono
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.hyprsunset.temperature + "K"
                    color: Theme.selFg
                    font.pixelSize: Theme.fontSizeLabel
                    font.family: Theme.fontMono
                    font.bold: true
                }
            }
            
            Slider {
                id: tempSlider
                Layout.fillWidth: true
                from: 1000
                to: 10000
                value: root.hyprsunset.temperature
                stepSize: 100

                background: Rectangle {
                    x: tempSlider.leftPadding
                    y: tempSlider.topPadding + tempSlider.availableHeight / 2 - height / 2
                    implicitWidth: 200
                    implicitHeight: 4
                    width: tempSlider.availableWidth
                    height: implicitHeight
                    radius: Theme.radiusSmall
                    color: Theme.border
                    opacity: Theme.opacitySoft

                    Rectangle {
                        width: tempSlider.visualPosition * parent.width
                        height: parent.height
                        color: Theme.selBg
                        radius: Theme.radiusSmall
                    }
                }

                handle: Rectangle {
                    x: tempSlider.leftPadding + tempSlider.visualPosition * (tempSlider.availableWidth - width)
                    y: tempSlider.topPadding + tempSlider.availableHeight / 2 - height / 2
                    implicitWidth: 14
                    implicitHeight: 14
                    radius: Theme.radiusHandle
                    color: Theme.selFg
                }

                // Commit on release: onMoved per step would spawn a hyprctl
                // process up to ~10x/second during a drag.
                onPressedChanged: {
                    if (!pressed)
                        root.hyprsunset.setTemperature(value)
                }
            }
        }

        // Gamma Slider
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSmall
            enabled: root.hyprsunset.enabled
            opacity: enabled ? 1.0 : 0.4
            
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Gamma"
                    color: Theme.fg
                    font.pixelSize: Theme.fontSizeLabel
                    font.family: Theme.fontMono
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: root.hyprsunset.gamma + "%"
                    color: Theme.selFg
                    font.pixelSize: Theme.fontSizeLabel
                    font.family: Theme.fontMono
                    font.bold: true
                }
            }
            
            Slider {
                id: gammaSlider
                Layout.fillWidth: true
                from: 10
                to: 100
                value: root.hyprsunset.gamma
                stepSize: 1

                background: Rectangle {
                    x: gammaSlider.leftPadding
                    y: gammaSlider.topPadding + gammaSlider.availableHeight / 2 - height / 2
                    implicitWidth: 200
                    implicitHeight: 4
                    width: gammaSlider.availableWidth
                    height: implicitHeight
                    radius: Theme.radiusSmall
                    color: Theme.border
                    opacity: Theme.opacitySoft

                    Rectangle {
                        width: gammaSlider.visualPosition * parent.width
                        height: parent.height
                        color: Theme.selBg
                        radius: Theme.radiusSmall
                    }
                }

                handle: Rectangle {
                    x: gammaSlider.leftPadding + gammaSlider.visualPosition * (gammaSlider.availableWidth - width)
                    y: gammaSlider.topPadding + gammaSlider.availableHeight / 2 - height / 2
                    implicitWidth: 14
                    implicitHeight: 14
                    radius: Theme.radiusHandle
                    color: Theme.selFg
                }

                // Commit on release (see temperature slider).
                onPressedChanged: {
                    if (!pressed)
                        root.hyprsunset.setGamma(value)
                }
            }
        }
        
        Components.StyledButton {
            id: resetBtn
            text: "RESET"
            bordered: true
            Layout.alignment: Qt.AlignHCenter
            onClicked: {
                root.hyprsunset.setTemperature(3500);
                root.hyprsunset.setGamma(100);
            }
        }
    }
}
