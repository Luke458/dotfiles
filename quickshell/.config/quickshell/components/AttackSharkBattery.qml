pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../services"
import "."

Item {
    id: root

    implicitWidth: layout.implicitWidth + Theme.controlPadding
    implicitHeight: 24

    function statusColor() {
        if (AttackSharkMetrics.hasBattery && AttackSharkMetrics.battery <= 15)
            return Theme.negative;
        if (AttackSharkMetrics.stale)
            return Theme.yellow;
        if (!AttackSharkMetrics.connected && !AttackSharkMetrics.hasBattery)
            return Theme.negative;
        if (AttackSharkMetrics.hasBattery && AttackSharkMetrics.battery <= 30)
            return Theme.yellow;
        return Theme.fg;
    }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: Theme.spacingSmall

        Text {
            text: "\u{efba}"
            color: root.statusColor()
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontSizeTitle
        }

        Text {
            text: {
                if (AttackSharkMetrics.loading && !AttackSharkMetrics.hasBattery)
                    return "...";
                if (AttackSharkMetrics.hasBattery)
                    return AttackSharkMetrics.battery + "%";
                return AttackSharkMetrics.hasError ? "N/A" : "--";
            }
            color: root.statusColor()
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeBar
        }
    }
}
