pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import "../services"

Item {
    id: root

    Component.onCompleted: NetworkService.beginDetails()
    Component.onDestruction: NetworkService.endDetails()

    implicitWidth: 380
    implicitHeight: Math.min(560, layout.implicitHeight + 40)

    signal itemTriggered()

    property var pendingConnect: null
    property int networksRevision: 0
    readonly property var networkList: {
        // networksRevision forces recompute when the scan model mutates.
        void root.networksRevision;
        return NetworkService.sortedWifiNetworks();
    }

    Connections {
        target: NetworkService.wifiDevice && NetworkService.wifiDevice.networks ? NetworkService.wifiDevice.networks : null
        function onValuesChanged() {
            root.networksRevision++;
            if (root.pendingConnect && root.pendingConnect.connected)
                root.pendingConnect = null;
        }
    }

    function securityGlyph(security) {
        switch (security) {
        case WifiSecurityType.Open:
        case WifiSecurityType.Owe:
            return "";
        case WifiSecurityType.Unknown:
            return "";
        default:
            return "\uf023"; // lock
        }
    }

    function strengthGlyph(strength) {
        if (strength >= 80) return "\uf1eb";
        if (strength >= 60) return "\ue1d8";
        if (strength >= 40) return "\ue1d9";
        return "\ueba9";
    }

    function requestConnect(network) {
        if (!network)
            return;
        if (network.connected)
            return;
        if (NetworkService.networkIsOpen(network) || network.known) {
            NetworkService.connectToNetwork(network, "");
            return;
        }
        pendingConnect = network;
        passphraseField.text = "";
        passphraseField.forceActiveFocus();
    }

    function submitPassphrase() {
        if (!pendingConnect)
            return;
        if (passphraseField.text.length === 0)
            return;
        if (NetworkService.connectToNetwork(pendingConnect, passphraseField.text)) {
            pendingConnect = null;
            passphraseField.text = "";
        }
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Theme.spacingLarge
        spacing: Theme.spacingLarge

        // ── Hero ──────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingMedium

            Text {
                text: NetworkService.connected ? "\uf1eb" : "\uf6ab"
                font.family: Theme.fontIcon
                font.pixelSize: Theme.fontSizeDisplaySmall
                color: NetworkService.connected ? Theme.selFg : Theme.fg
            }

            ColumnLayout {
                spacing: Theme.spacingXSmall
                Layout.fillWidth: true

                Text {
                    text: NetworkService.wiredConnected
                        ? "WIRED"
                        : (NetworkService.wifiConnected ? NetworkService.activeWifiName.toUpperCase() : "DISCONNECTED")
                    color: Theme.selFg
                    font.pixelSize: Theme.panelTitleSize
                    font.family: Theme.fontMono
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: NetworkService.address.length > 0 ? NetworkService.address : "no address"
                    color: Theme.fg
                    font.pixelSize: Theme.panelBodySize
                    font.family: Theme.fontMono
                    opacity: Theme.opacityMuted
                }
            }

            StyledButton {
                id: disconnectButton
                visible: NetworkService.connected
                iconText: "\uf011"
                Accessible.name: "Disconnect network"
                enabled: !NetworkService.disconnecting
                bordered: true
                onClicked: {
                    NetworkService.disconnectDevice(NetworkService.activeDevice);
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.border
            opacity: Theme.opacityVerySubtle
        }

        // ── Controls row ──────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingMedium

            Text {
                text: "WIFI"
                color: Theme.fg
                font.pixelSize: Theme.panelBodySize
                font.family: Theme.fontMono
                font.bold: true
                Layout.fillWidth: true
            }

            StyledSwitch {
                checked: NetworkService.wifiEnabled
                Accessible.name: "Wi-Fi"
                enabled: NetworkService.wifiDevice !== null && Networking.wifiHardwareEnabled
                onToggled: NetworkService.setWifiEnabled(!checked)
            }
        }

        Text {
            visible: NetworkService.wifiDevice !== null && !Networking.wifiHardwareEnabled
            text: "Wi-Fi hardware is disabled"
            color: Theme.yellow
            font.pixelSize: Theme.panelCaptionSize
            font.family: Theme.fontMono
        }

        Text {
            visible: NetworkService.wiredDevice !== null
            text: NetworkService.wiredConnected
                ? "ETHERNET · connected" + (NetworkService.wiredDevice.linkSpeed > 0 ? " · " + NetworkService.wiredDevice.linkSpeed + " Mb/s" : "")
                : "ETHERNET · no link"
            color: Theme.fg
            font.pixelSize: Theme.panelCaptionSize
            font.family: Theme.fontMono
            opacity: Theme.opacitySecondary
        }

        // ── Passphrase prompt ─────────────────────────────────────────────
        ColumnLayout {
            visible: root.pendingConnect !== null
            Layout.fillWidth: true
            spacing: Theme.spacingSmall

            Text {
                text: "PASSWORD FOR " + (root.pendingConnect ? String(root.pendingConnect.name).toUpperCase() : "")
                color: Theme.selFg
                font.pixelSize: Theme.panelCaptionSize
                font.family: Theme.fontMono
                font.bold: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSmall

                StyledTextField {
                    id: passphraseField
                    Layout.fillWidth: true
                    echoMode: TextInput.Password
                    Accessible.name: "Wi-Fi password"

                    onAccepted: root.submitPassphrase()
                    Keys.onEscapePressed: event => { // qmllint disable signal-handler-parameters
                        event.accepted = true;
                        root.pendingConnect = null;
                        passphraseField.text = "";
                    } // qmllint enable signal-handler-parameters
                }

                StyledButton {
                    id: connectButton
                    text: "CONNECT"
                    enabled: passphraseField.text.length > 0
                    selected: true
                    onClicked: root.submitPassphrase()
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: NetworkService.errorMessage.length > 0
            text: NetworkService.errorMessage
            color: Theme.negative
            font.family: Theme.fontMono
            font.pixelSize: Theme.panelBodySize
            wrapMode: Text.Wrap
        }

        // ── Network list ──────────────────────────────────────────────────
        Text {
            text: "NETWORKS"
            color: Theme.fg
            font.pixelSize: Theme.panelBodySize
            font.family: Theme.fontMono
            font.bold: true
            opacity: Theme.opacitySecondaryLow
        }

        ListView {
            id: networkListView
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 320)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            spacing: Theme.spacingCompact
            model: root.networkList

            delegate: Rectangle {
                id: networkRow
                required property int index
                required property var modelData
                width: networkListView.width
                implicitHeight: 34
                radius: Theme.radiusMedium
                color: networkRow.rowHovered ? Theme.menuHover : Theme.transparent

                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: modelData.name || "Hidden network"
                Keys.onReturnPressed: root.requestConnect(modelData)
                Keys.onSpacePressed: root.requestConnect(modelData)
                border.width: activeFocus ? 1 : 0
                border.color: Theme.selBg

                readonly property bool isOpen: NetworkService.networkIsOpen(modelData)

                MouseArea {
                    id: networkTap
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.requestConnect(networkRow.modelData)
                }
                readonly property bool rowHovered: networkTap.containsMouse

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.controlPadding
                    anchors.rightMargin: Theme.controlPadding
                    spacing: Theme.spacingMedium

                    Text {
                        text: root.strengthGlyph(networkRow.modelData.signalStrength || 0)
                        font.family: Theme.fontIcon
                        font.pixelSize: Theme.fontSizeLabel
                        color: networkRow.modelData.connected ? Theme.selFg : Theme.fg
                    }

                    Text {
                        text: networkRow.modelData.name || "(hidden network)"
                        color: networkRow.modelData.connected ? Theme.selFg : Theme.fg
                        font.pixelSize: Theme.panelBodySize
                        font.family: Theme.fontMono
                        font.bold: networkRow.modelData.connected
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        visible: root.securityGlyph(networkRow.modelData.security).length > 0
                        text: root.securityGlyph(networkRow.modelData.security)
                        font.family: Theme.fontIcon
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.fg
                        opacity: Theme.opacityMuted
                    }

                    Text {
                        visible: networkRow.modelData.known && !networkRow.modelData.connected
                        text: "SAVED"
                        font.pixelSize: Theme.panelCaptionSize
                        font.family: Theme.fontMono
                        color: Theme.fg
                        opacity: Theme.opacitySecondary
                    }

                    Text {
                        visible: networkRow.modelData.connected
                        text: "\uf00c"
                        font.family: Theme.fontIcon
                        font.pixelSize: Theme.fontSizeLabel
                        color: Theme.positive
                    }
                }
            }
        }

        Text {
            visible: root.networkList.length === 0
            text: !NetworkService.wifiDevice ? "No Wi-Fi adapter" : !NetworkService.wifiEnabled ? "Wi-Fi is off" : "No networks found · scanning"
            color: Theme.fg
            font.pixelSize: Theme.panelBodySize
            font.family: Theme.fontMono
            opacity: Theme.opacityMuted
            Layout.alignment: Qt.AlignHCenter
        }
    }
}
