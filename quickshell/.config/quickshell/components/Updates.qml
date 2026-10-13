pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../services" as Services
import "."

Item {
    id: root
    property bool forceHovered: false
    readonly property bool hovered: forceHovered || clickArea.containsMouse
    readonly property bool hasError: ["packages", "aur", "mise"]
        .some(source => Services.Updates.sourceError(source) !== "")
    readonly property color statusColor: Services.Updates.checking ? Theme.yellow
        : hasError ? Theme.negative
        : Services.Updates.total > 0 ? Theme.selFg : Theme.positive

    implicitWidth: layout.implicitWidth + Theme.controlPadding
    implicitHeight: 24
    signal clicked()

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: Theme.spacingSmall

        IconImage {
            source: Services.Updates.total > 0
                ? "file:///usr/share/icons/hicolor/scalable/apps/cachy-update_updates-available-blue.svg"
                : "file:///usr/share/icons/hicolor/scalable/apps/cachy-update-blue.svg"
            implicitWidth: 20
            implicitHeight: 20
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
        }
        Text {
            text: Services.Updates.checking && Services.Updates.lastChecked === 0
                ? "..." : String(Services.Updates.total)
            color: root.hovered ? Theme.selFg : root.statusColor
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeBar
            font.bold: Services.Updates.total > 0
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
