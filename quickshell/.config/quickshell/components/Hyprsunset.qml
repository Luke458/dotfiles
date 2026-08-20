import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

MouseArea {
    id: root
    required property var hyprsunset
    property bool forceHovered: false

    implicitWidth: layout.implicitWidth + 10
    implicitHeight: 24
    hoverEnabled: true
    
    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: Theme.spacingSmall

        IconImage {
            source: root.hyprsunset.enabled ? "image://icon/weather-clouds-night" : "image://icon/weather-clear-day"
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            opacity: root.hyprsunset.enabled ? 1.0 : 0.6
        }

        Text {
            text: root.hyprsunset.enabled ? root.hyprsunset.temperature + "K" : "OFF"
            color: (root.forceHovered || root.containsMouse) ? Theme.selBg : (root.hyprsunset.enabled ? Theme.selFg : Theme.fg)
            font.pixelSize: Theme.fontSizeBody
            font.family: Theme.fontMono
            font.bold: root.hyprsunset.enabled
        }
    }
    
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    
    onClicked: (mouse) => {
        if (mouse.button === Qt.RightButton) {
            root.hyprsunset.toggle();
        } else {
            root.itemTriggered();
        }
    }
    
    signal itemTriggered()
}
