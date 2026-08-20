pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Widgets
import "../services"

Item {
    id: root

    signal requestClose()
    
    implicitWidth: 200
    implicitHeight: layout.implicitHeight + 40
    
    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Theme.sectionPadding
        spacing: Theme.spacingMedium

        Repeater {
            model: [
                { label: "LOCK", icon: "system-lock-screen", action: () => Power.lock() },
                { label: "SUSPEND", icon: "system-suspend", action: () => Power.suspend() },
                { label: "REBOOT", icon: "system-reboot", action: () => Power.reboot() },
                { label: "POWER OFF", icon: "system-shutdown", action: () => Power.poweroff() },
                { label: "LOGOUT", icon: "system-log-out", action: () => Power.logout() }
            ]

            delegate: Button {
                id: btn
                required property var modelData
                Layout.fillWidth: true
                flat: true
                
                background: Rectangle {
                    implicitHeight: 40
                    radius: Theme.radiusMedium
                    color: btn.hovered ? Theme.hover : Theme.transparent
                }
                
                contentItem: RowLayout {
                    spacing: Theme.spacingLarge
                    IconImage {
                        source: "image://icon/" + btn.modelData.icon
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20
                    }
                    Text {
                        text: btn.modelData.label
                        color: btn.hovered ? Theme.selFg : Theme.fg
                        font.pixelSize: Theme.fontSizeBar
                        font.family: Theme.fontMono
                        font.bold: true
                    }
                }

                onClicked: {
                    root.requestClose();
                    btn.modelData.action();
                }
            }
        }
    }
}
