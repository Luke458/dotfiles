import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Luke.Quickshell.Pinentry
import Quickshell.Wayland
import Quickshell.Widgets
import "../services"
import "." as Components

PanelWindow { // qmllint disable uncreatable-type
    id: root

    property bool activeMonitor: false
    readonly property var request: Pinentry.request
    readonly property bool showing: Pinentry.active && activeMonitor
    readonly property bool needsSecret: root.request && root.request.mode === PinentryRequest.GetPin
    readonly property string titleText: root.request && root.request.title
        ? root.request.title.toUpperCase()
        : (root.needsSecret ? "GPG PASSPHRASE" : "PINENTRY")
    readonly property string okText: root.request && root.request.okLabel
        ? root.request.okLabel
        : (root.needsSecret ? "Unlock" : "OK")
    readonly property string cancelText: root.request && root.request.cancelLabel ? root.request.cancelLabel : "Cancel"
    readonly property string notOkText: root.request && root.request.notOkLabel ? root.request.notOkLabel : "No"
    readonly property bool needsRepeat: root.needsSecret && root.request && root.request.repeatLabel !== ""
    property string localError: ""

    visible: showing

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-pinentry"
    WlrLayershell.keyboardFocus: showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.exclusiveZone: -1

    color: Components.Theme.scrim

    function resetInput() {
        passwordField.text = "";
        repeatField.text = "";
        localError = "";
        focusTimer.restart();
    }

    function submit() {
        if (!root.request) {
            return;
        }

        if (root.needsSecret) {
            if (root.needsRepeat && passwordField.text !== repeatField.text) {
                root.localError = root.request.repeatError || "Passphrases do not match.";
                repeatField.text = "";
                repeatField.forceActiveFocus();
                return;
            }

            Pinentry.submit(passwordField.text);
            passwordField.text = "";
            repeatField.text = "";
        } else {
            Pinentry.accept();
        }

        focusTimer.restart();
    }

    function reject() {
        Pinentry.reject();
        passwordField.text = "";
        repeatField.text = "";
    }

    function cancel() {
        Pinentry.cancel();
        passwordField.text = "";
        repeatField.text = "";
    }

    function refocus() {
        if (root.needsSecret) {
            passwordField.forceActiveFocus();
        } else {
            submitButton.forceActiveFocus();
        }
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
        onTriggered: root.refocus()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.refocus()
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
                    source: "image://icon/dialog-password"
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    Layout.alignment: Qt.AlignTop
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingXSmall

                    Text {
                        text: root.titleText
                        color: Components.Theme.selFg
                        font.pixelSize: Theme.fontSizeTitle
                        font.family: Theme.fontMono
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.request ? root.request.description : ""
                        color: Components.Theme.fg
                        font.pixelSize: Theme.fontSizeLabel
                        font.family: Theme.fontMono
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                        visible: text !== ""
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
                text: root.request && root.request.keyInfo ? "Key: " + root.request.keyInfo : ""
                color: Components.Theme.fg
                opacity: Theme.opacityStrong
                font.pixelSize: Theme.fontSizeBody
                font.family: Theme.fontMono
                wrapMode: Text.WrapAnywhere
                Layout.fillWidth: true
                visible: text !== ""
            }

            Text {
                text: root.localError || (root.request ? root.request.error : "")
                color: Components.Theme.red
                font.pixelSize: Theme.fontSizeBody
                font.family: Theme.fontMono
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                visible: text !== ""
            }

            TextField {
                id: passwordField
                Layout.fillWidth: true
                visible: root.needsSecret
                focus: root.showing && root.needsSecret
                enabled: root.needsSecret
                echoMode: TextInput.Password
                color: Components.Theme.selFg
                selectedTextColor: Components.Theme.selFg
                selectionColor: Components.Theme.selBg
                font.pixelSize: Theme.fontSizeBar
                font.family: Theme.fontMono
                placeholderText: root.request && root.request.prompt ? root.request.prompt : "Passphrase"
                placeholderTextColor: Components.Theme.fg
                onAccepted: {
                    if (root.needsRepeat) {
                        repeatField.forceActiveFocus();
                    } else {
                        submitButton.clicked();
                    }
                }
                onTextChanged: root.localError = ""
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

            TextField {
                id: repeatField
                Layout.fillWidth: true
                visible: root.needsRepeat
                enabled: root.needsRepeat
                echoMode: TextInput.Password
                color: Components.Theme.selFg
                selectedTextColor: Components.Theme.selFg
                selectionColor: Components.Theme.selBg
                font.pixelSize: Theme.fontSizeBar
                font.family: Theme.fontMono
                placeholderText: root.request && root.request.repeatLabel ? root.request.repeatLabel : "Repeat passphrase"
                placeholderTextColor: Components.Theme.fg
                onAccepted: submitButton.clicked()
                onTextChanged: root.localError = ""
                Keys.onEscapePressed: (event) => {
                    root.cancel();
                    event.accepted = true;
                }

                background: Rectangle {
                    implicitHeight: 34
                    color: Components.Theme.fieldBg
                    border.color: repeatField.activeFocus ? Components.Theme.selBg : Components.Theme.border
                    border.width: 1
                    radius: Theme.radiusMedium
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingComfortable

                Item {
                    Layout.fillWidth: true
                }

                Button {
                    id: cancelButton
                    text: root.cancelText
                    flat: true
                    visible: root.request && !root.request.oneButton
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
                    id: notOkButton
                    text: root.notOkText
                    flat: true
                    visible: root.request && !root.needsSecret && !root.request.oneButton && root.request.notOkLabel
                    onClicked: root.reject()

                    background: Rectangle {
                        implicitWidth: 86
                        implicitHeight: 32
                        radius: Theme.radiusMedium
                        color: notOkButton.hovered ? Components.Theme.hover : Components.Theme.transparent
                        border.color: Components.Theme.border
                        border.width: 1
                    }

                    contentItem: Text {
                        text: notOkButton.text
                        color: Components.Theme.fg
                        font.pixelSize: Theme.fontSizeLabel
                        font.family: Theme.fontMono
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    id: submitButton
                    text: root.okText
                    enabled: root.request !== null
                    onClicked: root.submit()
                    Keys.onEscapePressed: (event) => {
                        root.cancel();
                        event.accepted = true;
                    }

                    background: Rectangle {
                        implicitWidth: Math.max(86, submitButton.implicitContentWidth + 28)
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
}
