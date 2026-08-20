pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import "." as Components

Row {
    id: root
    spacing: 0

    // Received from Bar.qml
    property string monitorName: ""
    property real wheelAccumulator: 0
    property bool wheelLocked: false

    function cycleWorkspace(direction) {
        const items = [];
        for (let index = 0; index < workspaceRepeater.count; index++) {
            const item = workspaceRepeater.itemAt(index);
            if (item && item.visible)
                items.push(item);
        }

        if (items.length < 2)
            return;

        items.sort((left, right) => left.modelData.id - right.modelData.id);
        let activeIndex = items.findIndex(item => item.modelData.active);
        if (activeIndex < 0)
            activeIndex = direction > 0 ? -1 : 0;

        const nextIndex = (activeIndex + direction + items.length) % items.length;
        items[nextIndex].modelData.activate();
    }

    function handleWheel(wheel) {
        const angleY = wheel.angleDelta.y;
        const pixelY = wheel.pixelDelta.y;
        const delta = angleY !== 0 ? angleY : pixelY;
        const horizontalDelta = wheel.angleDelta.x !== 0 ? wheel.angleDelta.x : wheel.pixelDelta.x;

        if (Math.abs(horizontalDelta) > Math.abs(delta)) {
            wheel.accepted = false;
            return;
        }

        if (delta === 0)
            return;

        wheel.accepted = true;
        if (wheelLocked)
            return;

        wheelAccumulator += delta;
        const threshold = angleY !== 0 ? 120 : 40;
        if (Math.abs(wheelAccumulator) < threshold)
            return;

        cycleWorkspace(wheelAccumulator < 0 ? 1 : -1);
        wheelAccumulator = 0;
        wheelLocked = true;
        wheelCooldown.restart();
    }

    Timer {
        id: wheelCooldown
        interval: 120
        onTriggered: root.wheelLocked = false
    }

    Repeater {
        id: workspaceRepeater
        model: Hyprland.workspaces

        delegate: Rectangle {
            id: workspaceItem
            required property var modelData

            readonly property string workspaceName: modelData.name ?? ""
            readonly property bool belongsToMonitor: modelData.monitor && modelData.monitor.name === root.monitorName
            readonly property bool isSpecialWorkspace: workspaceName.startsWith("special:")
            
            // Special workspaces are shown by SpecialWorkspaceIndicator instead.
            visible: belongsToMonitor && !isSpecialWorkspace
            width: visible ? 30 : 0
            height: 24
            clip: true
            
            // Simplified styling using MouseArea.containsMouse
            color: (modelData.active || mouseArea.containsMouse) 
                ? Components.Theme.selection
                : Components.Theme.transparent

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                enabled: workspaceItem.visible
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: workspaceItem.modelData.activate()
                onWheel: wheel => root.handleWheel(wheel)
            }

            Text {
                anchors.fill: parent
                text: workspaceItem.workspaceName
                color: (workspaceItem.modelData.active || mouseArea.containsMouse) ? Components.Theme.selFg : Components.Theme.fg
                font.pixelSize: Theme.fontSizeBar
                font.family: Theme.fontMono
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }
    }
}
