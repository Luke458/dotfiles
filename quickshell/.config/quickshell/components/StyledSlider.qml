import QtQuick
import QtQuick.Controls

Slider {
    id: control
    // A single commit after a pointer drag; immediate commits for keyboard input.
    signal committed(real newValue)
    property bool dragChanged: false
    property real dragValue: 0
    implicitHeight: 24
    implicitWidth: 200
    focusPolicy: Qt.StrongFocus
    opacity: enabled ? 1 : Theme.opacityDisabled
    onMoved: {
        if (pressed) {
            dragValue = value;
            dragChanged = true;
        } else
            committed(value);
    }
    onPressedChanged: {
        if (!pressed && dragChanged) {
            dragChanged = false;
            committed(dragValue);
        }
    }
    background: Rectangle {
        x: control.leftPadding
        y: control.topPadding + control.availableHeight / 2 - height / 2
        width: control.availableWidth
        implicitHeight: 4
        height: implicitHeight
        color: Theme.border
        Rectangle {
            x: control.mirrored ? parent.width - width : 0
            width: control.position * parent.width
            height: parent.height
            color: Theme.selBg
        }
    }
    handle: Rectangle {
        x: control.leftPadding + control.visualPosition * (control.availableWidth - width)
        y: control.topPadding + control.availableHeight / 2 - height / 2
        implicitWidth: 12
        implicitHeight: 12
        color: control.pressed || control.visualFocus ? Theme.selBg : Theme.selFg
        border.width: control.visualFocus ? 1 : 0
        border.color: Theme.selFg
    }
}
