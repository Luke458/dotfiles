pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../services"

Item {
    id: root
    
    implicitWidth: 400
    implicitHeight: Math.min(600, layout.implicitHeight + 60)
    
    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Theme.sectionPadding
        spacing: Theme.spacingLarge

        RowLayout {
            Layout.fillWidth: true
            
            Text {
                text: "NOTIFICATIONS"
                color: Theme.selFg
                font.pixelSize: Theme.fontSizeDisplaySmall
                font.family: Theme.fontMono
                font.bold: true
                Layout.fillWidth: true
            }

            Button {
                id: dndButton
                text: Notifications.doNotDisturb ? "DND On" : "DND Off"
                flat: true
                onClicked: Notifications.doNotDisturb = !Notifications.doNotDisturb

                background: Rectangle {
                    implicitWidth: 82
                    implicitHeight: 30
                    radius: Theme.radiusMedium
                    color: Theme.controlFill(dndButton.activeFocus, dndButton.hovered, Notifications.doNotDisturb)
                    border.color: Theme.controlBorder(dndButton.activeFocus, dndButton.hovered, Notifications.doNotDisturb)
                    border.width: 1
                }

                contentItem: Text {
                    text: dndButton.text
                    color: Theme.controlText(dndButton.activeFocus, dndButton.hovered, Notifications.doNotDisturb, dndButton.enabled)
                    font.pixelSize: Theme.fontSizeLabel
                    font.family: Theme.fontMono
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Button {
                id: clearAllBtn
                text: "Clear All"
                flat: true
                onClicked: Notifications.clearAll()
                
                background: Rectangle {
                    implicitWidth: 100
                    implicitHeight: 30
                    radius: Theme.radiusMedium
                    color: Theme.controlFill(clearAllBtn.activeFocus, clearAllBtn.hovered, false)
                }
                
                contentItem: Text {
                    text: clearAllBtn.text
                    color: Theme.controlText(clearAllBtn.activeFocus, clearAllBtn.hovered, false, clearAllBtn.enabled)
                    font.pixelSize: Theme.fontSizeLabel
                    font.family: Theme.fontMono
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.border
            opacity: Theme.opacitySoft
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true

            ListView {
                model: Notifications.history
                spacing: Theme.spacingMedium
                delegate: NotificationCard {
                    required property var model
                    width: parent ? parent.width : 0
                    summary: model.summary !== undefined ? model.summary : summary
                    body: model.body !== undefined ? model.body : body
                    appIcon: model.appIcon !== undefined ? model.appIcon : appIcon
                    time: model.time !== undefined ? model.time : ""
                    trackingId: model.trackingId !== undefined ? model.trackingId : ""
                    showTime: true
                    notification: null
                    expandable: true
                }
                
                footer: Text {
                    width: parent ? parent.width : 0
                    height: 100
                    text: "NO NOTIFICATIONS"
                    color: Theme.fg
                    font.pixelSize: Theme.fontSizeTitle
                    font.family: Theme.fontMono
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    visible: Notifications.history.count === 0
                }
            }
        }
    }
}
