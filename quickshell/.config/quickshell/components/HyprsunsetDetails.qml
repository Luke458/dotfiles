import QtQuick
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
                Accessible.name: "Night light"
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

            StyledSlider {
                id: tempSlider
                Accessible.name: "Color temperature"
                Layout.fillWidth: true
                from: 1000
                to: 10000
                Binding on value {
                    restoreMode: Binding.RestoreNone
                    value: root.hyprsunset.temperature
                    when: !tempSlider.pressed
                }
                stepSize: 100

                onCommitted: newValue => root.hyprsunset.setTemperature(newValue)
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

            StyledSlider {
                id: gammaSlider
                Accessible.name: "Gamma"
                Layout.fillWidth: true
                from: 10
                to: 100
                Binding on value {
                    restoreMode: Binding.RestoreNone
                    value: root.hyprsunset.gamma
                    when: !gammaSlider.pressed
                }
                stepSize: 1

                onCommitted: newValue => root.hyprsunset.setGamma(newValue)
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
