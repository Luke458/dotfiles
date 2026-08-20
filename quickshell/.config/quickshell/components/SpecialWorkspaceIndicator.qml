import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "." as Components

MouseArea {
    id: root

    required property var screen

    readonly property var monitor: screen ? Hyprland.monitorFor(screen) : null
    readonly property string activeSpecial: monitor?.lastIpcObject?.specialWorkspace?.name ?? ""
    readonly property string label: activeSpecial.startsWith("special:")
        ? activeSpecial.slice("special:".length)
        : activeSpecial

    visible: label.length > 0
    implicitWidth: visible ? indicatorLayout.implicitWidth + 12 : 0
    implicitHeight: 24
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor

    onClicked: {
        if (label.length > 0) {
            toggleSpecial(label)
        }
    }

    function luaString(value) {
        return "\"" + String(value)
            .replace(/\\/g, "\\\\")
            .replace(/"/g, "\\\"")
            .replace(/\n/g, "\\n")
            .replace(/\r/g, "\\r") + "\""
    }

    function toggleSpecial(name) {
        if (Hyprland.usingLua) {
            Hyprland.dispatch("hl.dsp.workspace.toggle_special(" + luaString(name) + ")")
        } else {
            Hyprland.dispatch("togglespecialworkspace " + name)
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            const name = event.name;
            if (["activespecial", "focusedmon", "workspace", "moveworkspace"].includes(name)) {
                Hyprland.refreshMonitors();
                Hyprland.refreshWorkspaces();
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusNone
        color: root.containsMouse
            ? Components.Theme.selectionStrong
            : Components.Theme.selectionMedium
    }

    RowLayout {
        id: indicatorLayout
        anchors.centerIn: parent
        spacing: Theme.spacingSmall

        Text {
            text: "\u{f02d}"
            color: root.containsMouse ? Components.Theme.selFg : Components.Theme.yellow
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontSizeBar
        }

        Text {
            text: root.label
            color: root.containsMouse ? Components.Theme.selFg : Components.Theme.fg
            font.pixelSize: Theme.fontSizeLabel
            font.family: Theme.fontMono
            font.bold: true
        }
    }
}
