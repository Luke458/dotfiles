pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import "../services"
import "../components" as Components

Rectangle {
    id: root

    color: Components.Theme.lockScreenBg

    function focusPassword(): void {
        Qt.callLater(() => passwordField.forceActiveFocus());
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(400, Math.max(0, root.width - Components.Theme.spacingHero))
        spacing: Components.Theme.spacingDisplay

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: -10

            Text {
                text: Qt.formatDateTime(Timekeeping.now, "HH:mm")
                color: Components.Theme.selFg
                font.pixelSize: Components.Theme.fontSizeClock
                font.family: Components.Theme.fontMono
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: Qt.formatDateTime(Timekeeping.now, "dddd, MMMM d").toUpperCase()
                color: Components.Theme.fg
                font.pixelSize: Components.Theme.fontSizeHeadingLarge
                font.family: Components.Theme.fontMono
                font.letterSpacing: 2
                Layout.alignment: Qt.AlignHCenter
                opacity: Components.Theme.opacitySecondaryHigh
            }
        }

        Item {
            Layout.preferredHeight: Components.Theme.spacingMedium
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: Components.Theme.spacingLarge

            Text {
                text: String(Quickshell.env("USER") || Quickshell.env("LOGNAME") || "").toUpperCase()
                color: Components.Theme.selFg
                font.pixelSize: Components.Theme.fontSizeDisplayLarge
                font.family: Components.Theme.fontMono
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.maximumWidth: 320
                Layout.preferredHeight: 45
                Layout.alignment: Qt.AlignHCenter
                color: Components.Theme.fieldBg
                border.color: Lock.authFailed
                    ? Components.Theme.red
                    : (passwordField.activeFocus ? Components.Theme.selBg : Components.Theme.border)
                border.width: 1
                radius: Components.Theme.radiusMedium

                TextInput {
                    id: passwordField
                    anchors.fill: parent
                    anchors.margins: Components.Theme.controlPadding
                    color: Components.Theme.selFg
                    font.pixelSize: Components.Theme.fontSizeDisplaySmall
                    font.family: Components.Theme.fontMono
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    readOnly: Lock.authInProgress
                    cursorVisible: activeFocus && !readOnly
                    activeFocusOnTab: true
                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                    verticalAlignment: TextInput.AlignVCenter
                    horizontalAlignment: TextInput.AlignHCenter
                    focus: true

                    onTextEdited: Lock.clearFailure()
                    onAccepted: {
                        if (Lock.tryUnlock(text))
                            clear();
                    }

                    Keys.onEscapePressed: clear()
                }
            }

            Text {
                text: Lock.authInProgress
                    ? "AUTHENTICATING…"
                    : (Lock.authFailed ? "ACCESS DENIED" : "ENTER PASSWORD")
                color: Lock.authFailed ? Components.Theme.red : Components.Theme.fg
                font.pixelSize: Components.Theme.fontSizeLabel
                font.family: Components.Theme.fontMono
                font.bold: true
                opacity: Lock.authFailed ? Components.Theme.opacityOpaque : Components.Theme.opacitySecondaryLow
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    Connections {
        target: Lock

        function onLockedChanged(): void {
            passwordField.clear();
            if (Lock.locked)
                root.focusPassword();
        }
    }

    Component.onCompleted: focusPassword()
}
