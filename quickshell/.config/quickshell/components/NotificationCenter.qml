pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../services"

Item {
    id: root
    
    implicitWidth: 400
    implicitHeight: 460
    
    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Theme.sectionPadding
        spacing: Theme.spacingLarge

        SectionHeading {
            text: "NOTIFICATIONS"
            font.pixelSize: Theme.fontSizeTitle
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingComfortable
            StyledButton {
                text: Notifications.doNotDisturb ? "DND On" : "DND Off"
                selected: Notifications.doNotDisturb
                bordered: true
                onClicked: Notifications.doNotDisturb = !Notifications.doNotDisturb
            }
            Item { Layout.fillWidth: true }
            StyledButton {
                text: "Clear all"
                bordered: true
                enabled: Notifications.history.count > 0
                onClicked: Notifications.clearAll()
            }
        }

        Divider { Layout.fillWidth: true }

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
                    summary: model.summary !== undefined ? model.summary : ""
                    body: model.body !== undefined ? model.body : ""
                    appIcon: model.appIcon !== undefined ? model.appIcon : ""
                    time: model.time !== undefined ? model.time : ""
                    trackingId: model.trackingId !== undefined ? model.trackingId : ""
                    showTime: true
                    notification: null
                    expandable: true
                }
                
                footer: Text {
                    width: parent ? parent.width : 0
                    height: visible ? 100 : 0
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
