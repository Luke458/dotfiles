pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../services"
import "."

// Microphone mute toggle. Hidden when PipeWire has no default source.
Item {
    id: root

    property bool forceHovered: false
    readonly property bool hovered: forceHovered || clickArea.containsMouse
    readonly property bool moduleActive: Volume.audioSource !== null

    implicitWidth: layout.implicitWidth + Theme.controlPadding
    implicitHeight: 24
    visible: moduleActive

    signal toggled()

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
    }

    MouseArea {
        id: clickArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Volume.toggleMicMute();
            root.toggled();
        }
        onWheel: wheel => Volume.changeMicVolume(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
    }
}
