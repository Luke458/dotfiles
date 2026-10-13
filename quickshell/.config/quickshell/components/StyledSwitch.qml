import QtQuick

// On/off switch matching the shell's control language: accent track and
// light knob when on, sunken field with border when off. Rectangular by
// default to match the shell's sharp-corner aesthetic; set `rounded` for a
// pill variant. The caller owns the value: bind `checked` and flip it in
// response to `toggled()`.
Item {
    id: root

    property bool checked: false
    property bool busy: false
    property bool rounded: false
    property int trackHeight: 20
    property int trackWidth: 38
    readonly property int knobSize: trackHeight - 6
    readonly property int knobInset: 3
    readonly property real cornerRadius: rounded ? trackHeight / 2 : Theme.radiusSmall

    signal toggled()

    activeFocusOnTab: true
    opacity: enabled ? 1 : Theme.opacityDisabled
    Accessible.role: Accessible.CheckBox
    Accessible.checkable: true
    Accessible.checked: checked
    Accessible.onPressAction: if (enabled && !busy) toggled()
    Keys.onSpacePressed: event => {
        if (enabled && !busy && !event.isAutoRepeat) toggled();
        event.accepted = true;
    }
    Keys.onReturnPressed: event => {
        if (enabled && !busy && !event.isAutoRepeat) toggled();
        event.accepted = true;
    }

    implicitWidth: trackWidth
    implicitHeight: trackHeight

    Rectangle {
        id: track
        anchors.fill: parent
        radius: root.cornerRadius
        color: root.checked ? Theme.selBg : Theme.fieldBg
        border.color: root.activeFocus ? Theme.selFg : (root.checked ? Theme.selBg : Theme.border)
        border.width: 1

        Rectangle {
            id: knob
            width: root.knobSize
            height: root.knobSize
            radius: root.rounded ? width / 2 : Theme.radiusSmall
            anchors.verticalCenter: parent.verticalCenter
            x: root.checked ? track.width - width - root.knobInset : root.knobInset
            color: root.checked ? Theme.selFg : Theme.fg
            opacity: root.busy ? Theme.opacityMuted : 1.0

        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.busy ? Qt.BusyCursor : Qt.PointingHandCursor
        onClicked: {
            root.forceActiveFocus(Qt.MouseFocusReason);
            if (!root.busy) root.toggled();
        }
    }
}
