import QtQuick
import Quickshell.Hyprland
import "."

Rectangle {
    id: root
    property bool active: false
    
    implicitHeight: 24
    
    color: active ? Theme.selection : Theme.transparent
    
    Text {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingSmall
        anchors.rightMargin: Theme.spacingSmall
        
        text: (root.active && Hyprland.activeToplevel) ? Hyprland.activeToplevel.title : ""
        color: Theme.selFg
        font.pixelSize: Theme.fontSizeBar
        font.family: Theme.fontMono
        elide: Text.ElideRight
        maximumLineCount: 1
        verticalAlignment: Text.AlignVCenter
    }
}
