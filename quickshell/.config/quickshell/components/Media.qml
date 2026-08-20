import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../services"

MouseArea {
    id: root
    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight
    
    signal itemTriggered()
    
    onClicked: (mouse) => {
        if (mouse.button === Qt.RightButton) {
            Media.togglePlayPause();
        } else {
            root.itemTriggered();
        }
    }

    acceptedButtons: Qt.LeftButton | Qt.RightButton

    RowLayout {
        id: layout
        // Removed anchors.fill: parent to avoid circular dependency on implicitWidth
        spacing: 0
        
        IconImage {
            id: mediaIcon
            Layout.preferredWidth: 14
            Layout.preferredHeight: 14
            source: {
                if (Media.playbackState === 1) return "image://icon/media-playback-pause"
                return "image://icon/media-playback-start"
            }
        }
    }
}
