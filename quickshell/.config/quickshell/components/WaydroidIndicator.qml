pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../services" as Services
import "."

Item {
    id: root

    property bool forceHovered: false
    readonly property bool hovered: forceHovered || clickArea.containsMouse
    readonly property color statusColor: {
        if (Services.Waydroid.busy)
            return Theme.yellow;
        if (Services.Waydroid.loading && Services.Waydroid.lastUpdated.getTime() <= 0)
            return Theme.yellow;
        if (!Services.Waydroid.available || Services.Waydroid.errorMessage.length > 0)
            return Theme.negative;
        if (Services.Waydroid.sessionRunning)
            return Theme.positive;
        if (Services.Waydroid.serviceActive)
            return Theme.selBg;
        return Theme.fg;
    }

    implicitWidth: layout.implicitWidth + Theme.controlPadding
    implicitHeight: 24

    signal clicked()

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: Theme.spacingSmall

        Text {
            text: "\uf17b"
            color: root.hovered ? Theme.selBg : root.statusColor
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontSizeTitle
        }

        Text {
            text: {
                if (Services.Waydroid.busy)
                    return "…";
                if (Services.Waydroid.sessionRunning)
                    return "RUNNING";
                if (Services.Waydroid.serviceActive)
                    return "READY";
                return "OFF";
            }
            color: root.hovered ? Theme.selBg : root.statusColor
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
            font.bold: Services.Waydroid.sessionRunning
        }
    }

    MouseArea {
        id: clickArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
