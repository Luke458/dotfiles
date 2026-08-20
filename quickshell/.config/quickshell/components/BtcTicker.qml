pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../services"
import "."

Item {
    id: root
    property bool forceHovered: false
    readonly property bool hovered: forceHovered || clickArea.containsMouse

    implicitWidth: layout.implicitWidth + 10
    implicitHeight: 24

    signal clicked()

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: Theme.spacingSmall

        Text {
            text: "\u{f15a}"
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontSizeTitle
            color: root.hovered ? Theme.selBg : Theme.fg
        }

        Text {
            text: {
                if (Btc.loading && !Btc.hasCachedData) return "..."
                if (Btc.hasError && !Btc.hasCachedData) return "N/A"
                if (!Btc.currentAud) return "--"
                return root.formatAud(Btc.currentAud)
            }
            color: root.hovered ? Theme.selBg : Theme.fg
            font.pixelSize: Theme.fontSizeBar
            font.family: Theme.fontMono
        }
    }

    function formatAud(value) {
        return "A$" + Math.round(value).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",")
    }

    MouseArea {
        id: clickArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Btc.refresh()
            root.clicked()
        }
    }
}
