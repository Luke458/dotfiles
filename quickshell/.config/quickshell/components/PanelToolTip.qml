pragma ComponentBehavior: Bound

import QtQuick
import "."

// Inline tooltip. Declare as a child of the hovered item and bind `visible`:
//
//   PanelToolTip { visible: mouse.containsMouse; text: "Forget network" }
//
// Deliberately a plain Item rather than Qt Quick Controls ToolTip: our panels
// are Wayland layer surfaces, where control popups can fail to render.
Item {
    id: root

    property string text: ""
    property color panelForeground: Theme.fg
    property color panelBackground: Theme.bgSolid
    property color panelBorder: Theme.border
    // Placement relative to the parent item; override to flip above the anchor.
    property bool above: false
    property bool alignLeft: false

    visible: false
    z: 100
    implicitWidth: frame.width
    implicitHeight: frame.height

    x: parent ? (alignLeft ? 0 : (parent.width - width) / 2) : 0
    y: parent ? (above ? -height - Theme.spacingXSmall : parent.height + Theme.spacingXSmall) : 0

    Rectangle {
        id: frame
        width: label.implicitWidth + Theme.spacingCompact * 2
        height: label.implicitHeight + Theme.spacingXSmall * 2
        color: root.panelBackground
        border.color: root.panelBorder
        border.width: 1
        radius: Theme.radiusMedium

        Text {
            id: label
            anchors.centerIn: parent
            text: root.text
            color: root.panelForeground
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
