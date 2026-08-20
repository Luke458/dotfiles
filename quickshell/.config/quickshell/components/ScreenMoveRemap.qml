import QtQuick

// Remap a long-lived layer surface after its monitor moves in the compositor
// layout. Hyprland can otherwise leave it at the monitor's previous origin.
Item {
    id: root

    required property var window
    readonly property var screen: window ? window.screen : null
    property bool remapping: false

    visible: false

    Timer {
        id: settleTimer
        interval: 200
        onTriggered: root.remapping = true
    }

    Timer {
        interval: 50
        running: root.remapping
        onTriggered: root.remapping = false
    }

    Connections {
        target: root.screen
        function onXChanged() { settleTimer.restart(); }
        function onYChanged() { settleTimer.restart(); }
    }
}
