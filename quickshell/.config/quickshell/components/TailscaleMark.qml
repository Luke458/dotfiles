pragma ComponentBehavior: Bound

import QtQuick

// Native rendering of the Tailscale mark (3x3 dot grid) so it stays crisp in
// tiny bar slots, with an optional "off" slash and a "needs login" badge.
Item {
    id: root

    property real iconSize: 15
    property color color: Theme.fg
    property color badgeColor: Theme.negative
    property bool crossed: false
    property bool warning: false

    width: iconSize
    height: iconSize
    implicitWidth: iconSize
    implicitHeight: iconSize

    readonly property real dotSize: Math.max(2, root.iconSize * 0.24)
    readonly property real mid: (root.iconSize - root.dotSize) / 2
    readonly property real end: root.iconSize - root.dotSize

    Dot { x: 0; y: 0; opacity: 0.24 }
    Dot { x: root.mid; y: 0; opacity: 0.24 }
    Dot { x: root.end; y: 0; opacity: 0.24 }
    Dot { x: 0; y: root.mid; opacity: 1.0 }
    Dot { x: root.mid; y: root.mid; opacity: 1.0 }
    Dot { x: root.end; y: root.mid; opacity: 1.0 }
    Dot { x: 0; y: root.end; opacity: 0.24 }
    Dot { x: root.mid; y: root.end; opacity: 1.0 }
    Dot { x: root.end; y: root.end; opacity: 0.24 }

    Rectangle {
        visible: root.crossed
        anchors.centerIn: parent
        width: parent.width * 1.22
        height: Math.max(2, parent.height * 0.14)
        radius: height / 2
        color: root.color
        rotation: -45
    }

    Rectangle {
        visible: root.warning
        width: Math.max(7, parent.width * 0.42)
        height: width
        radius: width / 2
        color: root.badgeColor
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        Text {
            anchors.centerIn: parent
            text: "!"
            color: Theme.bgSolid
            font.family: Theme.fontMono
            font.pixelSize: Math.max(6, parent.height * 0.72)
            font.bold: true
        }
    }

    component Dot: Rectangle {
        width: root.dotSize
        height: root.dotSize
        radius: width / 2
        color: root.color
    }
}
