pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../services"
import "."

// Recording indicator: left click opens the recording flyout. Red with a live
// timer while a screen or webcam recording runs.
Item {
    id: root

    property bool forceHovered: false
    readonly property bool hovered: forceHovered || clickArea.containsMouse
    readonly property bool moduleActive: true

    implicitWidth: layout.implicitWidth + Theme.controlPadding
    implicitHeight: 24

    signal itemTriggered()

    readonly property string elapsedText: {
        const tick = Timekeeping.now.getTime();
        if (!RecordingService.anyActive) return "";
        const screenSec = RecordingService.elapsedSec(RecordingService.screenStartedAt);
        const webcamSec = RecordingService.elapsedSec(RecordingService.webcamStartedAt);
        return RecordingService.formatElapsed(Math.max(screenSec, webcamSec));
    }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: Theme.spacingSmall

        Text {
            text: "\uf111"
            color: root.hovered ? Theme.selFg : (RecordingService.anyActive ? Theme.negative : Theme.fg)
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontSizeBar
        }

        Text {
            visible: root.elapsedText !== ""
            text: root.elapsedText
            color: root.hovered ? Theme.selFg : Theme.negative
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeBar
        }
    }

    MouseArea {
        id: clickArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.itemTriggered()
    }
}
