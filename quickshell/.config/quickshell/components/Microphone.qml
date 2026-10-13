pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../services"
import "."

// Microphone indicator. Left click opens the input flyout, right click toggles
// mute, and the wheel adjusts input volume.
Item {
    id: root

    property bool forceHovered: false
    readonly property bool hovered: forceHovered || clickArea.containsMouse
    readonly property bool moduleActive: Volume.audioSource !== null

    implicitWidth: layout.implicitWidth + Theme.controlPadding
    implicitHeight: 24
    visible: moduleActive

    signal itemTriggered()

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: Theme.spacingSmall

        Text {
            text: Volume.micMuted ? "\uf131" : "\uf130"
            color: root.hovered ? Theme.selFg : (Volume.micMuted ? Theme.negative : Theme.fg)
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontSizeTitle
        }

        Text {
            text: Volume.micMuted ? "Muted" : Volume.micPercent + "%"
            color: root.hovered ? Theme.selFg : (Volume.micMuted ? Theme.negative : Theme.fg)
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

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                Volume.toggleMicMute();
            else
                root.itemTriggered();
        }

        onWheel: wheel => {
            if (wheel.angleDelta.y !== 0)
                Volume.changeMicVolume(wheel.angleDelta.y > 0 ? 0.02 : -0.02);
        }
    }
}
