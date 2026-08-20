import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../services"

Item {
    id: root

    property bool forceHovered: false
    readonly property bool hovered: forceHovered || clickArea.containsMouse
    readonly property color statusColor: {
        if (Mullvad.hasError)
            return Theme.red;
        if (Mullvad.connected)
            return Theme.green;
        if (Mullvad.connecting || Mullvad.disconnecting)
            return Theme.yellow;
        if (Mullvad.lockedDown || Mullvad.lockdownMode)
            return Theme.yellow;
        return Theme.fg;
    }

    implicitWidth: layout.implicitWidth + 10
    implicitHeight: 24

    signal itemTriggered()

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: Theme.spacingSmall

        IconImage {
            source: "image://icon/mullvad-vpn"
            Layout.preferredWidth: 15
            Layout.preferredHeight: 15
            opacity: Mullvad.connected || Mullvad.connecting || Mullvad.lockedDown || Mullvad.lockdownMode ? 1.0 : 0.65
        }

        Text {
            text: Mullvad.indicatorLabel
            color: root.hovered ? Theme.selBg : root.statusColor
            font.pixelSize: Theme.fontSizeBody
            font.family: Theme.fontMono
            font.bold: Mullvad.connected || Mullvad.lockedDown || Mullvad.lockdownMode
        }
    }

    MouseArea {
        id: clickArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                Mullvad.toggleConnection();
            } else if (mouse.button === Qt.MiddleButton) {
                Mullvad.reconnect();
            } else {
                root.itemTriggered();
            }
        }
    }
}
