import QtQuick
import QtQuick.Layouts
import "../services"
import "."

Item {
    id: clock
    property bool forceHovered: false
    readonly property bool hovered: forceHovered || clickArea.containsMouse

    implicitWidth: layout.implicitWidth + 10
    implicitHeight: 24

    signal clicked()

    function getClockIcon() {
        const h = Timekeeping.now.getHours();
        var h12 = (h % 12) === 0 ? 12 : (h % 12);
        return String.fromCodePoint(0xF144B + (h12 - 1));
    }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: Theme.spacingSmall

        Text {
            text: clock.getClockIcon()
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontSizeTitle
            color: clock.hovered ? Theme.selBg : Theme.fg
        }

        Text {
            text: Timekeeping.barTime
            color: clock.hovered ? Theme.selBg : Theme.fg
            font.pixelSize: Theme.fontSizeBar
            font.family: Theme.fontMono
        }
    }

    MouseArea {
        id: clickArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: clock.clicked()
    }
}
