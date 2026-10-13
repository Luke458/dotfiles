import QtQuick
import QtQuick.Controls

TextField {
    id: control
    implicitHeight: 32
    leftPadding: Theme.controlPadding
    rightPadding: Theme.controlPadding
    topPadding: Theme.spacingSmall
    bottomPadding: Theme.spacingSmall
    color: Theme.fg
    placeholderTextColor: Theme.placeholderFg
    selectionColor: Theme.selBg
    selectedTextColor: Theme.selFg
    font.family: Theme.fontMono
    font.pixelSize: Theme.panelBodySize
    selectByMouse: true
    verticalAlignment: TextInput.AlignVCenter
    opacity: enabled ? 1 : Theme.opacityDisabled
    Accessible.name: placeholderText
    background: Rectangle {
        color: Theme.fieldBg
        border.width: 1
        border.color: control.activeFocus ? Theme.selBg : Theme.border
        radius: Theme.radiusMedium
    }
}
