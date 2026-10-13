import QtQuick
import QtQuick.Layouts
import "../services"

Item {
    id: root

    property bool forceHovered: false
    readonly property bool hovered: forceHovered || clickArea.containsMouse
    readonly property bool up: NetworkService.connected

    implicitWidth: layout.implicitWidth + 10
    implicitHeight: 24

    signal itemTriggered()

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: Theme.spacingSmall

        Text {
            text: {
                if (NetworkService.wiredConnected) return "\u{ef44}"; // rj45
                if (!NetworkService.wifiDevice && !NetworkService.wiredDevice) return "\u{f128}";
                if (NetworkService.connected) {
                    const strength = NetworkService.activeWifiStrength;
                    if (strength >= 80) return "\u{f1eb}";
                    if (strength >= 60) return "\u{f0925}";
                    if (strength >= 40) return "\u{f0922}";
                    return "\u{f091f}";
                }
                return NetworkService.wifiEnabled ? "\u{f05aa}" : "\u{f128}";
            }
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontSizeBody
            color: root.hovered ? Theme.selFg : (root.up ? Theme.fg : Theme.fg)
        }

        Text {
            visible: !NetworkService.connected
            text: NetworkService.indicatorLabel
            color: root.hovered ? Theme.selFg : Theme.fg
            font.pixelSize: Theme.fontSizeBody
            font.family: Theme.fontMono
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
