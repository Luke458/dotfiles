pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "."

// Inline confirmation card for destructive actions inside a flyout or overlay.
// Declare as a child of a full-size container and drive it with open()/close()
// or by binding `opened`. Keyboard owners can forward events to handleKey().
Item {
    id: root

    property bool opened: false
    property string title: ""
    property string message: ""
    property string cancelText: "Cancel"
    property string confirmText: "Confirm"
    property bool destructive: true
    property int selectedIndex: 1

    signal canceled()
    signal confirmed()

    visible: opened
    z: 1000

    function open(newTitle, newMessage) {
        if (newTitle !== undefined && newTitle !== null)
            title = String(newTitle);
        if (newMessage !== undefined && newMessage !== null)
            message = String(newMessage);
        opened = true;
        selectedIndex = 1;
    }

    function close() { opened = false; }

    // Returns true when the event was consumed; callers keep focus elsewhere.
    function handleKey(event) {
        if (!opened) return false;
        if (event.key === Qt.Key_Escape) {
            root.canceled();
            return true;
        }
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right
            || event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            root.selectedIndex = root.selectedIndex === 0 ? 1 : 0;
            return true;
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (root.selectedIndex === 0) root.canceled();
            else root.confirmed();
            return true;
        }
        return false;
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim

        MouseArea {
            anchors.fill: parent
            onClicked: root.canceled()
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - Theme.spacingPage, Theme.space(360))
        implicitHeight: content.implicitHeight + Theme.dialogPadding * 2
        color: Theme.bgSolid
        border.color: Theme.border
        border.width: 1
        radius: Theme.radiusMedium

        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: Theme.dialogPadding
            spacing: Theme.spacingSection

            Text {
                visible: root.title !== ""
                Layout.fillWidth: true
                text: root.title
                color: Theme.selFg
                font.family: Theme.fontMono
                font.pixelSize: Theme.panelTitleSize
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: root.message
                color: Theme.fg
                font.family: Theme.fontMono
                font.pixelSize: Theme.panelBodySize
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: Theme.spacingComfortable

                StyledButton {
                    text: root.cancelText
                    bordered: true
                    onClicked: root.canceled()
                }

                StyledButton {
                    text: root.confirmText
                    bordered: true
                    selected: true
                    tint: root.destructive ? Theme.negative : "transparent"
                    onClicked: root.confirmed()
                }
            }
        }
    }
}
