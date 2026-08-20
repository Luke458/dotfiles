import QtQuick
import "." as Components

MouseArea {
    id: root
    
    // State passed from parent
    required property bool inhibited
    signal toggle()

    implicitWidth: label.implicitWidth + 10
    implicitHeight: 24
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    Text {
        id: label

        // Appearance
        anchors.centerIn: parent
        text: root.inhibited ? "☕" : "💤"
        color: root.containsMouse ? Components.Theme.selBg : (root.inhibited ? Components.Theme.selBg : Components.Theme.fg)
        font.pixelSize: Theme.fontSizeDisplaySmall
        verticalAlignment: Text.AlignVCenter
    }

    onClicked: root.toggle()
}
