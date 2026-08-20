import QtQuick
import "." as Components
import "../services"

MouseArea {
    id: root
    
    readonly property string currentLayout: LayoutState.currentLayout
    
    implicitWidth: label.implicitWidth + 10
    implicitHeight: 24
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    Text {
        id: label

        anchors.centerIn: parent
        text: {
            if (root.currentLayout === "dwindle") return "[\\]"
            if (root.currentLayout === "master") return "[]="
            if (root.currentLayout === "scrolling") return "[>>]"
            return "><>"
        }
        color: root.containsMouse ? Components.Theme.selBg : Components.Theme.fg
        font.pixelSize: Theme.fontSizeBar
        font.family: Theme.fontMono
    }

    onClicked: LayoutState.toggle()
}
