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
            text: "\u{f00ed}"
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontSizeTitle
            color: root.hovered ? Theme.selBg : Theme.fg
        }

        Text {
            text: Qt.formatDateTime(Timekeeping.now, "ddd MMM d")
            color: root.hovered ? Theme.selBg : Theme.fg
            font.pixelSize: Theme.fontSizeBar
            font.family: Theme.fontMono
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
