pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"

PanelWindow { // qmllint disable uncreatable-type
    id: root

    property bool activeMonitor: false

    visible: activeMonitor && Notifications.popups.count > 0 && !remapGuard.remapping

    ScreenMoveRemap {
        id: remapGuard
        window: root
    }


    // Position top-right
    anchors {
        top: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-notifications"

    color: Theme.transparent

    // Size driven by layout
    implicitWidth: 362
    implicitHeight: view.contentHeight + 12

    ListView {
        id: view
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: Theme.spacingTiny
        anchors.rightMargin: Theme.spacingCompact
        width: 350
        height: view.contentHeight
        spacing: Theme.spacingMedium
        interactive: false

        model: Notifications.popups

        delegate: NotificationCard {
            required property var model
            width: 350
            summary: model.summary !== undefined ? model.summary : summary
            body: model.body !== undefined ? model.body : body
            appIcon: model.appIcon !== undefined ? model.appIcon : appIcon
            time: model.time !== undefined ? model.time : ""
            trackingId: model.trackingId !== undefined ? model.trackingId : ""
            showTime: false
            notification: null
            showTimeoutCircle: model.timeoutMs !== undefined && model.timeoutMs > 0
            timeoutDuration: model.timeoutMs !== undefined ? model.timeoutMs : 10000
        }

        // Entrance animation
        add: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: 300
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "x"
                from: 50
                to: 0
                duration: 300
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                property: "scale"
                from: 0.9
                to: 1.0
                duration: 300
                easing.type: Easing.OutCubic
            }
        }

        // Exit animation
        remove: Transition {
            NumberAnimation {
                property: "opacity"
                to: 0
                duration: 250
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                property: "x"
                to: 20
                duration: 250
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                property: "scale"
                to: 0.9
                duration: 250
                easing.type: Easing.InCubic
            }
        }

        // Animation when other items move to fill the gap
        displaced: Transition {
            NumberAnimation {
                properties: "y"
                duration: 300
                easing.type: Easing.OutCubic
            }
        }
    }
}
