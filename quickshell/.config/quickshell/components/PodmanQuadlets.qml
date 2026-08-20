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
        if (Services.PodmanQuadlets.errorMessage && !Services.PodmanQuadlets.hasData)
            return Theme.negative;
        if (Services.PodmanQuadlets.loading && !Services.PodmanQuadlets.hasData)
            return Theme.yellow;
        if (Services.PodmanQuadlets.failed > 0)
            return Theme.negative;
        if (Services.PodmanQuadlets.allHealthy)
            return Theme.positive;
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
            text: "\u{e842}"
            color: root.hovered ? Theme.selBg : root.statusColor
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontSizeTitle
        }

        Text {
            text: {
                if (Services.PodmanQuadlets.loading && !Services.PodmanQuadlets.hasData)
                    return "...";
                if (!Services.PodmanQuadlets.hasData)
                    return "--";
                return Services.PodmanQuadlets.healthy + "/" + Services.PodmanQuadlets.total;
            }
            color: root.hovered ? Theme.selBg : root.statusColor
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeBar
            font.bold: Services.PodmanQuadlets.failed > 0
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
