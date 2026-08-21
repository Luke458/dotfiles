import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../services"
import "." as Components

PanelWindow { // qmllint disable uncreatable-type
    id: root

    property bool activeMonitor: false
    readonly property var flow: Polkit.flow
    readonly property bool showing: Polkit.active && activeMonitor

    visible: showing

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-polkit"
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1

    color: Components.Theme.scrim

    function resetInput() {
        passwordField.text = "";
        focusTimer.restart();
    }

    function submit() {
        if (!root.flow) {
            return;
        }

        Polkit.submit(passwordField.text);
        passwordField.text = "";
        focusTimer.restart();
    }

    function cancel() {
        Polkit.cancel();
        passwordField.text = "";
    }

    onShowingChanged: {
        if (showing) {
            resetInput();
        }
    }

    Timer {
        id: focusTimer
        interval: 40
        repeat: false
        onTriggered: passwordField.forceActiveFocus()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: passwordField.forceActiveFocus()
    }

    Rectangle {
        id: card
        width: Math.min(460, root.width - 40)
        height: content.implicitHeight + 36
        anchors.centerIn: parent
        color: Components.Theme.bg
        border.color: Components.Theme.border
        border.width: 1
        radius: Theme.radiusLarge

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: Theme.dialogPadding
            spacing: Theme.spacingSection

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSection

                IconImage {
                    id: flowIcon
                    // Track the failed URL instead of assigning `source`
                    // imperatively, which would destroy the binding.
                    property string failedSource: ""
                    source: {
                        const resolved = root.flow && root.flow.iconName
                            ? "image://icon/" + root.flow.iconName
                            : "image://icon/dialog-password";
                        return resolved === failedSource ? "image://icon/dialog-password" : resolved;
                    }
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignTop
                    onStatusChanged: if (status === Image.Error) failedSource = root.flow && root.flow.iconName ? "image://icon/" + root.flow.iconName : ""
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingXSmall

                    Text {
                        text: "AUTHENTICATION REQUIRED"
                        color: Components.Theme.selFg
                        font.pixelSize: Theme.fontSizeTitle
                        font.family: Theme.fontMono
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.flow ? root.flow.message : ""
                        color: Components.Theme.fg
                        font.pixelSize: Theme.fontSizeLabel
                        font.family: Theme.fontMono
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Components.Theme.border
                opacity: Theme.opacityMuted
            }

            Text {
                text: root.flow && root.flow.selectedIdentity
                    ? "Authenticate as " + root.flow.selectedIdentity.displayName
                    : ""
                color: Components.Theme.fg
                opacity: Theme.opacityStrong
                font.pixelSize: Theme.fontSizeBody
                font.family: Theme.fontMono
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                visible: text !== ""
            }

            Text {
                text: root.flow ? root.flow.inputPrompt : ""
                color: Components.Theme.fg
                font.pixelSize: Theme.fontSizeLabel
                font.family: Theme.fontMono
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                visible: text !== ""
            }

            TextField {
                id: passwordField
                Layout.fillWidth: true
                focus: root.showing
                enabled: root.flow && root.flow.isResponseRequired
                echoMode: root.flow && root.flow.responseVisible ? TextInput.Normal : TextInput.Password
                color: Components.Theme.selFg
                selectedTextColor: Components.Theme.selFg
                selectionColor: Components.Theme.selBg
                font.pixelSize: Theme.fontSizeBar
                font.family: Theme.fontMono
                placeholderText: root.flow && root.flow.isResponseRequired ? "Password" : "Waiting for authentication request"
                placeholderTextColor: Components.Theme.fg
                onAccepted: submitButton.clicked()
                Keys.onEscapePressed: (event) => {
                    root.cancel();
                    event.accepted = true;
                }

                background: Rectangle {
                    implicitHeight: 34
                    color: Components.Theme.fieldBg
                    border.color: passwordField.activeFocus ? Components.Theme.selBg : Components.Theme.border
                    border.width: 1
                    radius: Theme.radiusMedium
                }
            }

            Text {
                text: root.flow ? root.flow.supplementaryMessage : ""
                color: root.flow && root.flow.supplementaryIsError ? Components.Theme.red : Components.Theme.fg
                opacity: text === "" ? 0 : 0.9
                font.pixelSize: Theme.fontSizeBody
                font.family: Theme.fontMono
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                visible: text !== ""
            }

            Text {
                text: "Authentication failed. Try again."
                color: Components.Theme.red
                font.pixelSize: Theme.fontSizeBody
                font.family: Theme.fontMono
                Layout.fillWidth: true
                visible: root.flow && root.flow.failed
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingComfortable

                Item {
                    Layout.fillWidth: true
                }

                Button {
                    id: cancelButton
                    text: "Cancel"
                    flat: true
                    onClicked: root.cancel()

                    background: Rectangle {
                        implicitWidth: 86
                        implicitHeight: 32
                        radius: Theme.radiusMedium
                        color: cancelButton.hovered ? Components.Theme.hover : Components.Theme.transparent
                        border.color: Components.Theme.border
                        border.width: 1
                    }

                    contentItem: Text {
                        text: cancelButton.text
                        color: Components.Theme.fg
                        font.pixelSize: Theme.fontSizeLabel
                        font.family: Theme.fontMono
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    id: submitButton
                    text: "Authenticate"
                    enabled: root.flow && root.flow.isResponseRequired
                    onClicked: root.submit()

                    background: Rectangle {
                        implicitWidth: 128
                        implicitHeight: 32
                        radius: Theme.radiusMedium
                        color: submitButton.enabled
                            ? (submitButton.hovered ? Components.Theme.lighter(Components.Theme.selBg, 1.15) : Components.Theme.selBg)
                            : Components.Theme.disabledSurface
                        border.color: submitButton.enabled ? Components.Theme.selBg : Components.Theme.border
                        border.width: 1
                    }

                    contentItem: Text {
                        text: submitButton.text
                        color: submitButton.enabled ? Components.Theme.selFg : Components.Theme.fg
                        opacity: submitButton.enabled ? 1 : 0.45
                        font.pixelSize: Theme.fontSizeLabel
                        font.family: Theme.fontMono
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }

    Connections {
        target: root.flow
        enabled: root.flow !== null

        function onIsResponseRequiredChanged() {
            root.resetInput();
        }

        function onAuthenticationFailed() {
            root.resetInput();
        }

        function onAuthenticationRequestCancelled() {
            passwordField.text = "";
        }

        function onAuthenticationSucceeded() {
            passwordField.text = "";
        }
    }
}
