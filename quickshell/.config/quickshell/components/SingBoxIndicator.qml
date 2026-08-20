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
        if (Services.SingBox.loading && Services.SingBox.routes.length === 0)
            return Theme.yellow;
        if (!Services.SingBox.active || Services.SingBox.errorMessage.length > 0)
            return Theme.negative;
        if (!Services.SingBox.liveSynchronized
                || !Services.SingBox.deploymentSynchronized)
            return Theme.yellow;
        return Theme.positive;
    }

    implicitWidth: layout.implicitWidth + Theme.controlPadding
    implicitHeight: 24

    signal clicked()

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: Theme.spacingSmall

        Text {
            text: "\u{f0ac}"
            color: root.hovered ? Theme.selBg : root.statusColor
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontSizeTitle
        }

        Text {
            text: Services.SingBox.loading && Services.SingBox.routes.length === 0
                ? "..." : Services.SingBox.total
            color: root.hovered ? Theme.selBg : root.statusColor
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeBar
            font.bold: !Services.SingBox.healthy
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
