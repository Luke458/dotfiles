pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../services" as Services
import "."

Item {
    id: root

    readonly property var ts: Services.Tailscale

    implicitWidth: 380
    implicitHeight: Math.min(560, contentColumn.implicitHeight + Theme.popupPadding * 2 + Theme.spacingSmall)

    signal itemTriggered()

    Component.onCompleted: ts.beginDetails()
    Component.onDestruction: ts.endDetails()

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        Column {
            id: contentColumn
            width: parent.width
            padding: Theme.panelPadding
            spacing: Theme.spacingContent

            // ── Hero ─────────────────────────────────────────────────────────
            RowLayout {
                width: parent.width - Theme.panelPadding * 2
                spacing: Theme.spacingMedium

                TailscaleMark {
                    iconSize: Theme.fontSizeDisplaySmall
                    color: root.ts.active ? Theme.selFg : Theme.fg
                    crossed: !root.ts.active && !root.ts.needsLogin
                    warning: root.ts.needsLogin
                    opacity: root.ts.active ? 1.0 : 0.55
                    Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingTiny

                    Text {
                        Layout.fillWidth: true
                        text: root.ts.selfName.length > 0 ? root.ts.selfName.toUpperCase() : "TAILSCALE"
                        color: Theme.selFg
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.panelTitleSize
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: {
                            const parts = [root.ts.statusText];
                            if (root.ts.selfIp.length > 0)
                                parts.push(root.ts.selfIp);
                            if (root.ts.active)
                                parts.push(root.ts.onlinePeerCount + "/" + root.ts.peers.length + " online");
                            return parts.join(" · ");
                        }
                        color: Theme.fg
                        opacity: Theme.opacityStrong
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.panelCaptionSize
                        elide: Text.ElideRight
                    }
                }

                IconButton {
                    glyph: "\uf021"
                    Accessible.name: "Refresh Tailscale"
                    available: !root.ts.busy
                    onActivated: root.ts.refresh()
                }

                StyledSwitch {
                    visible: root.ts.installed
                    checked: root.ts.active
                    Accessible.name: "Tailscale connection"
                    busy: root.ts.busy
                    Layout.alignment: Qt.AlignVCenter
                    onToggled: root.ts.toggle()
                }
            }

            Text {
                width: parent.width - Theme.panelPadding * 2
                visible: root.ts.errorMessage.length > 0
                text: root.ts.errorMessage
                color: Theme.negative
                font.family: Theme.fontMono
                font.pixelSize: Theme.panelCaptionSize
                wrapMode: Text.Wrap
            }

            Text {
                width: parent.width - Theme.panelPadding * 2
                visible: root.ts.errorMessage.length === 0 && root.ts.lastMessage.length > 0
                text: root.ts.lastMessage
                color: Theme.positive
                font.family: Theme.fontMono
                font.pixelSize: Theme.panelCaptionSize
                wrapMode: Text.Wrap
            }

            Text {
                width: parent.width - Theme.panelPadding * 2
                visible: !root.ts.installed
                text: "Tailscale CLI is not installed or not on PATH."
                color: Theme.fg
                opacity: Theme.opacitySecondary
                font.family: Theme.fontMono
                font.pixelSize: Theme.panelCaptionSize
                wrapMode: Text.Wrap
            }

            Text {
                width: parent.width - Theme.panelPadding * 2
                visible: root.ts.installed && !root.ts.active
                text: root.ts.needsLogin
                    ? "This device needs to be authorized."
                    : "Tailscale is disconnected. Turn it on to reach your tailnet."
                color: Theme.fg
                opacity: Theme.opacitySecondary
                font.family: Theme.fontMono
                font.pixelSize: Theme.panelCaptionSize
                wrapMode: Text.Wrap
            }

            // ── Exit nodes ───────────────────────────────────────────────────
            Divider {
                width: parent.width - Theme.panelPadding * 2
                visible: root.ts.active && root.ts.exitNodes.length > 0
            }

            Column {
                width: parent.width - Theme.panelPadding * 2
                spacing: Theme.spacingCompact
                visible: root.ts.active && root.ts.exitNodes.length > 0

                SectionHeading { text: "EXIT NODE" }

                Repeater {
                    model: root.ts.exitNodes
                    delegate: ExitRow {
                        width: parent ? parent.width : 0
                    }
                }
            }

            // ── Machines ─────────────────────────────────────────────────────
            Divider {
                width: parent.width - Theme.panelPadding * 2
                visible: root.ts.active
            }

            Column {
                width: parent.width - Theme.panelPadding * 2
                spacing: Theme.spacingCompact
                visible: root.ts.active

                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingComfortable

                    SectionHeading { text: "MACHINES" }
                    Item { Layout.fillWidth: true }

                    Text {
                        text: root.ts.onlinePeerCount + "/" + root.ts.peers.length + " online"
                        color: Theme.fg
                        opacity: Theme.opacitySecondary
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.panelCaptionSize
                    }
                }

                Text {
                    visible: root.ts.peers.length === 0
                    text: root.ts.loading ? "Loading…" : "No machines on this tailnet."
                    color: Theme.fg
                    opacity: Theme.opacitySecondary
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.panelCaptionSize
                }

                Repeater {
                    model: root.ts.peers
                    delegate: PeerRow {
                        width: parent ? parent.width : 0
                    }
                }
            }
        }
    }

    // Small square glyph button used for refresh and copy actions.
    component IconButton: StyledButton {
        property string glyph: ""
        property bool available: true
        signal activated()
        iconText: glyph
        enabled: available
        fixedWidth: 30
        bordered: true
        onClicked: activated()
    }

    component ExitRow: MouseArea {
        id: exitRow

        required property var modelData
        required property int index

        readonly property var peer: modelData
        readonly property bool activeExit: exitRow.peer ? exitRow.peer.ExitNode === true : false

        implicitHeight: 34
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: !root.ts.busy
        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: peer ? (peer.HostName || peer.DNSName || "Exit node") : "No exit node"
        Keys.onReturnPressed: root.ts.setExitNode(peer)
        Keys.onSpacePressed: root.ts.setExitNode(peer)
        opacity: enabled ? 1 : Theme.opacityDisabled
        onClicked: root.ts.setExitNode(exitRow.peer)

        Rectangle {
            anchors.fill: parent
            color: exitRow.activeExit
                ? Theme.selectionMedium
                : (exitRow.containsMouse ? Theme.menuHover : Theme.transparent)
            border.color: exitRow.activeFocus || exitRow.activeExit ? Theme.selBg : Theme.border
            border.width: 1
            radius: Theme.radiusMedium
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.controlPadding
            anchors.rightMargin: Theme.controlPadding
            spacing: Theme.spacingMedium

            Text {
                text: "\uf08b"
                color: exitRow.activeExit ? Theme.selFg : Theme.fg
                font.family: Theme.fontIcon
                font.pixelSize: Theme.fontSizeLabel
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                Layout.fillWidth: true
                text: exitRow.peer ? (exitRow.peer.DisplayName || exitRow.peer.HostName) : ""
                color: Theme.selFg
                font.family: Theme.fontMono
                font.pixelSize: Theme.panelCaptionSize
                font.bold: exitRow.activeExit
                elide: Text.ElideRight
            }

            Text {
                visible: exitRow.activeExit
                text: "ACTIVE"
                color: Theme.positive
                font.family: Theme.fontMono
                font.pixelSize: Theme.panelCaptionSize
                font.bold: true
            }
        }
    }

    component PeerRow: MouseArea {
        id: peerRow

        required property var modelData
        required property int index

        readonly property var peer: modelData
        readonly property bool online: peerRow.peer ? peerRow.peer.Online === true : false

        implicitHeight: peerContent.implicitHeight + Theme.spacingSmall * 2
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.ts.copyPeerIp(peerRow.peer)

        Rectangle {
            anchors.fill: parent
            color: peerRow.containsMouse ? Theme.menuHover : Theme.transparent
            radius: Theme.radiusMedium
        }

        RowLayout {
            id: peerContent
            anchors.fill: parent
            anchors.leftMargin: Theme.controlPadding
            anchors.rightMargin: Theme.spacingSmall
            spacing: Theme.spacingComfortable

            Text {
                text: root.ts.osIcon(peerRow.peer ? peerRow.peer.OS : "")
                color: peerRow.online ? Theme.selFg : Theme.fg
                opacity: peerRow.online ? 1.0 : Theme.opacityMuted
                font.family: Theme.fontIcon
                font.pixelSize: Theme.fontSizeLabel
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingTiny

                Text {
                    Layout.fillWidth: true
                    text: peerRow.peer ? peerRow.peer.HostName : ""
                    color: peerRow.online ? Theme.selFg : Theme.fg
                    opacity: peerRow.online ? 1.0 : Theme.opacityMuted
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.panelCaptionSize
                    font.bold: peerRow.online
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: {
                        const peer = peerRow.peer;
                        if (!peer)
                            return "";
                        const parts = [];
                        if (peer.TailscaleIPs && peer.TailscaleIPs.length > 0)
                            parts.push(peer.TailscaleIPs[0]);
                        if (peer.DNSName)
                            parts.push(peer.DNSName);
                        return parts.join(" · ");
                    }
                    color: Theme.fg
                    opacity: Theme.opacityMuted
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.panelCaptionSize
                    elide: Text.ElideRight
                }
            }

            IconButton {
                glyph: "\uf0c1"
                Accessible.name: "Copy IP address"
                available: peerRow.peer !== null && peerRow.peer.TailscaleIPs.length > 0
                onActivated: root.ts.copyPeerIp(peerRow.peer)
            }

            IconButton {
                glyph: "\uf0ac"
                Accessible.name: "Copy DNS name"
                available: peerRow.peer !== null && peerRow.peer.DNSName.length > 0
                onActivated: root.ts.copyPeerDns(peerRow.peer)
            }
        }
    }
}
