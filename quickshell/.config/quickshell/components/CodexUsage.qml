pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../services"
import "."

Item {
    id: root

    property bool forceHovered: false
    readonly property bool hovered: forceHovered || clickArea.containsMouse

    implicitWidth: layout.implicitWidth + Theme.controlPadding
    implicitHeight: 24

    signal clicked()

    function statusColor() {
        if (CodexUsageService.hasError && !CodexUsageService.hasData)
            return Theme.negative;
        if (CodexUsageService.stale)
            return Theme.yellow;
        if (!CodexUsageService.hasData)
            return Theme.fg;
        if (CodexUsageService.remainingPercent <= 20)
            return Theme.negative;
        if (CodexUsageService.remainingPercent <= 40)
            return Theme.yellow;
        return Theme.fg;
    }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: Theme.spacingSmall

        Text {
            text: "\u{f121}"
            color: root.hovered ? Theme.selBg : root.statusColor()
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontSizeTitle
        }

        Text {
            text: {
                if (CodexUsageService.loading && !CodexUsageService.hasData)
                    return "...";
                if (CodexUsageService.hasError && !CodexUsageService.hasData)
                    return "N/A";
                return CodexUsageService.hasData ? CodexUsageService.remainingPercent + "%" : "--";
            }
            color: root.hovered ? Theme.selBg : root.statusColor()
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeBar
        }
    }

    MouseArea {
        id: clickArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            CodexUsageService.refresh();
            root.clicked();
        }
    }
}
