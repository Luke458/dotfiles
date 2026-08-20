import QtQuick
import QtQuick.Layouts
import "../services"

Item {
    id: root
    property bool forceHovered: false
    readonly property bool hovered: forceHovered || clickArea.containsMouse

    implicitWidth: layout.implicitWidth + 10
    implicitHeight: 24

    signal itemTriggered()

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: Theme.spacingSmall

        Text {
            text: Volume.muted ? "\u{F0581}" : "\u{F057E}"
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontSizeTitle
            color: root.hovered ? Theme.selBg : (Volume.muted ? Theme.red : Theme.fg)
        }

        Text {
            text: Volume.muted ? "Muted" : Volume.volumePercent + "%"
            color: root.hovered ? Theme.selBg : Theme.fg
            font.pixelSize: Theme.fontSizeBar
            font.family: Theme.fontMono
        }
    }

    MouseArea {
        id: clickArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        
        onClicked: (mouse) => {
            if (mouse.button === Qt.LeftButton) {
                root.itemTriggered()
            } else if (mouse.button === Qt.RightButton) {
                Volume.toggleMute()
            }
        }

        onWheel: (wheel) => {
            if (wheel.angleDelta.y !== 0) {
                var delta = wheel.angleDelta.y > 0 ? 0.02 : -0.02
                Volume.changeVolume(delta)
            }
        }
    }
}
