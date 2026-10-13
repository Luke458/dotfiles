pragma ComponentBehavior: Bound

import QtQuick
import "../services" as Services
import "."

// Bar indicator for Tailscale. Left click opens the details flyout, right click
// toggles the connection, middle click refreshes.
Item {
    id: root

    property bool forceHovered: false
    readonly property var ts: Services.Tailscale
    readonly property bool hovered: forceHovered || clickArea.containsMouse
    readonly property color statusColor: {
        if (ts.errorMessage.length > 0 && !ts.active)
            return Theme.negative;
        if (ts.active)
            return Theme.positive;
        if (ts.busy || ts.needsLogin)
            return Theme.yellow;
        return Theme.fg;
    }

    implicitWidth: mark.width + Theme.controlPadding
    implicitHeight: 24

    signal itemTriggered()

    TailscaleMark {
        id: mark
        anchors.centerIn: parent
        iconSize: 15
        color: root.hovered ? Theme.selFg : root.statusColor
        crossed: !root.ts.active && !root.ts.needsLogin
        warning: root.ts.needsLogin
    }

    MouseArea {
        id: clickArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.ts.toggle();
            else if (mouse.button === Qt.MiddleButton)
                root.ts.refresh();
            else
                root.itemTriggered();
        }
    }
}
