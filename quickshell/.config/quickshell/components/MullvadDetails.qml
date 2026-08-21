pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets
import "../services"

Item {
    id: root

    Component.onCompleted: Mullvad.acquireDetails()
    Component.onDestruction: Mullvad.releaseDetails()

    implicitWidth: 480
    implicitHeight: Math.min(640, contentColumn.implicitHeight + 32)

    property var visibleLocations: {
        if (!Mullvad.locations)
            return [];
        return Mullvad.locationChoices(locationSearch.text);
    }

    function statusColor() {
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

    function choiceSelected(choice) {
        if (!choice)
            return false;
        if (choice.kind === "any")
            return Mullvad.relayConstraint === "" || Mullvad.relayConstraint === "any";
        if (choice.kind === "country")
            return Mullvad.relayConstraint === "country " + choice.countryCode;
        if (choice.kind === "city")
            return Mullvad.relayConstraint.indexOf("city " + choice.cityCode + ", " + choice.countryCode) !== -1;
        if (choice.kind === "host")
            return Mullvad.relayConstraint.indexOf("hostname " + choice.hostname) !== -1 || Mullvad.hostname === choice.hostname;
        return false;
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        Column {
            id: contentColumn
            width: parent.width
            padding: Theme.panelPadding
            spacing: Theme.spacingContent

            RowLayout {
                width: parent.width - 32
                spacing: Theme.spacingSection

                IconImage {
                    source: "image://icon/mullvad-vpn"
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    spacing: Theme.spacingTiny
                    Layout.fillWidth: true

                    Text {
                        text: "MULLVAD VPN"
                        color: Theme.selFg
                        font.pixelSize: Theme.fontSizeHeadingLarge
                        font.family: Theme.fontMono
                        font.bold: true
                    }

                    Text {
                        text: Mullvad.summary
                        color: Theme.fg
                        opacity: Theme.opacityStrong
                        font.pixelSize: Theme.fontSizeBody
                        font.family: Theme.fontMono
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    radius: Theme.radiusMedium
                    color: Theme.withAlpha(root.statusColor(), 0.16)
                    border.color: root.statusColor()
                    border.width: 1
                    implicitWidth: stateText.implicitWidth + 14
                    implicitHeight: 24

                    Text {
                        id: stateText
                        anchors.centerIn: parent
                        text: Mullvad.stateLabel
                        color: root.statusColor()
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontMono
                        font.bold: true
                    }
                }
            }

            Rectangle {
                width: parent.width - 32
                height: 1
                color: Theme.border
                opacity: Theme.opacitySubtle
            }

            RowLayout {
                width: parent.width - 32
                spacing: Theme.spacingComfortable

                StyledButton {
                    id: connectBtn
                    Layout.fillWidth: true
                    enabled: !Mullvad.commandRunning
                    tint: root.statusColor()
                    text: Mullvad.connected || Mullvad.connecting ? "DISCONNECT" : "CONNECT"
                    onClicked: Mullvad.toggleConnection()
                }

                StyledButton {
                    id: reconnectBtn
                    Layout.fillWidth: true
                    enabled: !Mullvad.commandRunning
                    bordered: true
                    text: "RECONNECT"
                    onClicked: Mullvad.reconnect()
                }

                StyledButton {
                    id: refreshBtn
                    fixedWidth: 38
                    enabled: !Mullvad.commandRunning
                    bordered: true
                    iconText: "\uf2f1"
                    onClicked: Mullvad.refreshAll()
                }
            }

            Column {
                width: parent.width - 32
                spacing: Theme.spacingComfortable

                RowLayout {
                    width: parent.width

                    Text {
                        text: "LOCATION"
                        color: Theme.selFg
                        font.pixelSize: Theme.fontSizeLabel
                        font.family: Theme.fontMono
                        font.bold: true
                        Layout.fillWidth: true
                    }

                    Text {
                        text: Mullvad.relayConstraintLabel
                        color: Theme.fg
                        opacity: Theme.opacitySecondaryHigh
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontMono
                        elide: Text.ElideRight
                        Layout.maximumWidth: 260
                    }
                }

                TextField {
                    id: locationSearch
                    width: parent.width
                    height: 34
                    placeholderText: Mullvad.locationsLoading ? "Loading locations" : "Search country or city"
                    placeholderTextColor: Theme.placeholderFg
                    color: Theme.selFg
                    selectionColor: Theme.selBg
                    selectedTextColor: Theme.selFg
                    font.pixelSize: Theme.fontSizeLabel
                    font.family: Theme.fontMono

                    background: Rectangle {
                        radius: Theme.radiusMedium
                        color: Theme.surfaceSubtle
                        border.color: locationSearch.activeFocus ? Theme.selBg : Theme.border
                        border.width: 1
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 220
                    color: Theme.shadow
                    border.color: Theme.border
                    border.width: 1
                    radius: Theme.radiusMedium
                    clip: true

                    ListView {
                        id: locationList
                        anchors.fill: parent
                        anchors.margins: Theme.spacingXSmall
                        clip: true
                        spacing: Theme.spacingTiny
                        model: root.visibleLocations

                        delegate: Button {
                            id: locationButton
                            required property var modelData
                            width: ListView.view.width
                            height: 34
                            flat: true
                            enabled: !Mullvad.commandRunning
                            readonly property bool selected: root.choiceSelected(locationButton.modelData)

                            background: Rectangle {
                                radius: Theme.radiusMedium
                                color: locationButton.selected ? Theme.selectionSoft : (locationButton.hovered ? Theme.hoverSoft : Theme.transparent)
                                border.width: locationButton.selected ? 1 : 0
                                border.color: Theme.selBg
                            }

                            contentItem: RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Theme.controlPadding
                                anchors.rightMargin: Theme.controlPadding
                                spacing: Theme.spacingMedium

                                Text {
                                    text: locationButton.modelData.kind === "any" ? "AUTO" : locationButton.modelData.kind.toUpperCase()
                                    color: locationButton.selected ? Theme.selBg : Theme.fg
                                    opacity: Theme.opacityProminent
                                    font.pixelSize: Theme.fontSizeCaption
                                    font.family: Theme.fontMono
                                    font.bold: true
                                    Layout.preferredWidth: 48
                                }

                                Text {
                                    text: locationButton.modelData.label
                                    color: locationButton.selected ? Theme.selFg : Theme.fg
                                    font.pixelSize: Theme.fontSizeLabel
                                    font.family: Theme.fontMono
                                    font.bold: locationButton.selected
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: locationButton.modelData.sublabel
                                    color: Theme.fg
                                    opacity: Theme.opacityMedium
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.family: Theme.fontMono
                                }
                            }

                            onClicked: Mullvad.setLocation(locationButton.modelData)
                        }
                    }
                }
            }

            Column {
                width: parent.width - 32
                spacing: Theme.spacingComfortable

                Text {
                    text: "CONNECTION"
                    color: Theme.selFg
                    font.pixelSize: Theme.fontSizeLabel
                    font.family: Theme.fontMono
                    font.bold: true
                }

                Repeater {
                    model: [
                        { label: "AUTO CONNECT", checked: Mullvad.autoConnect, action: value => Mullvad.setAutoConnect(value) },
                        { label: "LOCKDOWN MODE", checked: Mullvad.lockdownMode, action: value => Mullvad.setLockdownMode(value) },
                        { label: "LAN SHARING", checked: Mullvad.lanAllowed, action: value => Mullvad.setLanAllowed(value) },
                        { label: "IPV6", checked: Mullvad.ipv6, action: value => Mullvad.setIpv6(value) },
                        { label: "QUANTUM RESISTANT", checked: Mullvad.quantumResistant, action: value => Mullvad.setQuantumResistant(value) },
                        { label: "DAITA", checked: Mullvad.daita, action: value => Mullvad.setDaita(value) }
                    ]

                    delegate: RowLayout {
                        id: connectionSetting
                        required property var modelData
                        width: parent.width
                        height: 30
                        spacing: Theme.spacingSection

                        Text {
                            text: connectionSetting.modelData.label
                            color: Theme.fg
                            font.pixelSize: Theme.fontSizeBody
                            font.family: Theme.fontMono
                            Layout.fillWidth: true
                        }

                        StyledSwitch {
                            checked: connectionSetting.modelData.checked
                            busy: Mullvad.commandRunning
                            onToggled: connectionSetting.modelData.action(!checked)
                        }
                    }
                }
            }

            Column {
                width: parent.width - 32
                spacing: Theme.spacingComfortable

                Text {
                    text: "ACCOUNT"
                    color: Theme.selFg
                    font.pixelSize: Theme.fontSizeLabel
                    font.family: Theme.fontMono
                    font.bold: true
                }

                GridLayout {
                    width: parent.width
                    columns: 2
                    columnSpacing: 18
                    rowSpacing: 6

                    Text {
                        text: "DEVICE"
                        color: Theme.fg
                        opacity: Theme.opacityMedium
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontMono
                    }
                    Text {
                        text: Mullvad.deviceName.length > 0 ? Mullvad.deviceName : "Unknown"
                        color: Theme.fg
                        font.pixelSize: Theme.fontSizeBody
                        font.family: Theme.fontMono
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "ACCOUNT"
                        color: Theme.fg
                        opacity: Theme.opacityMedium
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontMono
                    }
                    Text {
                        text: Mullvad.accountMasked.length > 0 ? Mullvad.accountMasked : "Not signed in"
                        color: Theme.fg
                        font.pixelSize: Theme.fontSizeBody
                        font.family: Theme.fontMono
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "PAID UNTIL"
                        color: Theme.fg
                        opacity: Theme.opacityMedium
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontMono
                    }
                    Text {
                        text: Mullvad.accountExpiry.length > 0 ? Mullvad.accountExpiry : "Unknown"
                        color: Theme.fg
                        font.pixelSize: Theme.fontSizeBody
                        font.family: Theme.fontMono
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Text {
                        text: "VERSION"
                        color: Theme.fg
                        opacity: Theme.opacityMedium
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: Theme.fontMono
                    }
                    Text {
                        text: Mullvad.version.length > 0 ? Mullvad.version + (Mullvad.supported ? "" : " unsupported") : "Unknown"
                        color: Mullvad.supported ? Theme.fg : Theme.yellow
                        font.pixelSize: Theme.fontSizeBody
                        font.family: Theme.fontMono
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
