pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../services" as Services
import "."

Item {
    id: root

    implicitWidth: 540
    implicitHeight: Math.min(650, contentColumn.implicitHeight)

    readonly property var filteredApps: Services.Waydroid.apps.filter(app => {
        const needle = appSearch.text.trim().toLowerCase();
        return needle.length === 0
            || String(app.name).toLowerCase().includes(needle)
            || String(app.packageName).toLowerCase().includes(needle);
    })

    signal itemTriggered()

    Component.onCompleted: Services.Waydroid.beginDetails()
    Component.onDestruction: Services.Waydroid.endDetails()

    function statusColor() {
        if (!Services.Waydroid.available || Services.Waydroid.errorMessage.length > 0)
            return Theme.negative;
        if (Services.Waydroid.busy)
            return Theme.yellow;
        if (Services.Waydroid.sessionRunning)
            return Theme.positive;
        if (Services.Waydroid.serviceActive)
            return Theme.selBg;
        return Theme.fg;
    }

    function stateLabel() {
        if (Services.Waydroid.busy)
            return Services.Waydroid.actionName.toUpperCase();
        if (Services.Waydroid.sessionRunning)
            return "SESSION RUNNING";
        if (Services.Waydroid.serviceActive)
            return "SERVICE READY";
        return "STOPPED";
    }

    function containerStatusColor() {
        if (Services.Waydroid.containerState === "RUNNING")
            return Theme.positive;
        if (Services.Waydroid.containerState === "FROZEN")
            return Theme.yellow;
        return Theme.fg;
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
                width: parent.width - Theme.panelPadding * 2
                spacing: Theme.spacingSection

                Text {
                    text: "\uf17b"
                    color: root.statusColor()
                    font.family: Theme.fontIcon
                    font.pixelSize: Theme.fontSizeValueSmall
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingTiny

                    Text {
                        text: "WAYDROID"
                        color: Theme.selFg
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeHeadingLarge
                        font.bold: true
                    }

                    Text {
                        text: "Service " + (Services.Waydroid.serviceActive ? "active" : "stopped")
                            + " · Android session " + (Services.Waydroid.sessionRunning ? "running" : "stopped")
                        color: Theme.fg
                        opacity: Theme.opacityStrong
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeBody
                    }
                }

                Rectangle {
                    implicitWidth: stateText.implicitWidth + Theme.spacingSection
                    implicitHeight: 26
                    color: Theme.withAlpha(root.statusColor(), Theme.opacityVerySubtle)
                    border.color: root.statusColor()
                    border.width: 1
                    radius: Theme.radiusMedium

                    Text {
                        id: stateText
                        anchors.centerIn: parent
                        text: root.stateLabel()
                        color: root.statusColor()
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeCaption
                        font.bold: true
                    }
                }
            }

            Rectangle {
                width: parent.width - Theme.panelPadding * 2
                height: 1
                color: Theme.separator
            }

            RowLayout {
                width: parent.width - Theme.panelPadding * 2
                spacing: Theme.spacingComfortable

                Repeater {
                    model: [
                        {
                            label: "SYSTEM SERVICE",
                            value: Services.Waydroid.serviceActive ? "ACTIVE" : "STOPPED",
                            color: Services.Waydroid.serviceActive ? Theme.positive : Theme.fg
                        },
                        {
                            label: "ANDROID SESSION",
                            value: Services.Waydroid.sessionRunning ? "RUNNING" : "STOPPED",
                            color: Services.Waydroid.sessionRunning ? Theme.positive : Theme.fg
                        },
                        {
                            label: "ANDROID CONTAINER",
                            value: Services.Waydroid.containerState,
                            color: root.containerStatusColor()
                        }
                    ]

                    delegate: Rectangle {
                        id: statusCard
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: 54
                        color: Theme.withAlpha(statusCard.modelData.color, Theme.opacityBarelyVisible)
                        border.color: statusCard.modelData.color
                        border.width: 1
                        radius: Theme.radiusMedium

                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.spacingTiny

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: statusCard.modelData.value
                                color: statusCard.modelData.color
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeLabel
                                font.bold: true
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: statusCard.modelData.label
                                color: Theme.fg
                                opacity: Theme.opacityStrong
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeCaption
                            }
                        }
                    }
                }
            }

            RowLayout {
                width: parent.width - Theme.panelPadding * 2
                spacing: Theme.spacingComfortable

                Button {
                    id: containerButton
                    Layout.fillWidth: true
                    flat: true
                    enabled: Services.Waydroid.available && !Services.Waydroid.busy
                    onClicked: Services.Waydroid.serviceActive
                        ? Services.Waydroid.stopService()
                        : Services.Waydroid.startService()

                    background: Rectangle {
                        implicitHeight: 36
                        radius: Theme.radiusMedium
                        color: containerButton.hovered ? Theme.hover : Theme.transparent
                        border.color: Services.Waydroid.serviceActive ? Theme.negative : Theme.border
                        border.width: 1
                    }

                    contentItem: Text {
                        text: Services.Waydroid.serviceActive ? "STOP SERVICE" : "START SERVICE"
                        color: containerButton.hovered ? Theme.selFg : Theme.fg
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    id: sessionButton
                    Layout.fillWidth: true
                    flat: true
                    enabled: Services.Waydroid.available && !Services.Waydroid.busy
                    onClicked: Services.Waydroid.sessionRunning
                        ? Services.Waydroid.stopSession()
                        : Services.Waydroid.startSession()

                    background: Rectangle {
                        implicitHeight: 36
                        radius: Theme.radiusMedium
                        color: sessionButton.hovered ? Theme.selectionSoft : Theme.transparent
                        border.color: Services.Waydroid.sessionRunning ? Theme.negative : Theme.selBg
                        border.width: 1
                    }

                    contentItem: Text {
                        text: Services.Waydroid.sessionRunning ? "STOP SESSION" : "START SESSION"
                        color: sessionButton.hovered ? Theme.selFg : Theme.fg
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    id: fullUiButton
                    Layout.preferredWidth: 86
                    flat: true
                    enabled: Services.Waydroid.available && !Services.Waydroid.busy
                    onClicked: {
                        Services.Waydroid.showFullUi();
                        root.itemTriggered();
                    }

                    background: Rectangle {
                        implicitHeight: 36
                        radius: Theme.radiusMedium
                        color: fullUiButton.hovered ? Theme.selectionSoft : Theme.selectionSubtle
                        border.color: Theme.selBg
                        border.width: 1
                    }

                    contentItem: Text {
                        text: "FULL UI"
                        color: Theme.selFg
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    id: refreshButton
                    implicitWidth: 38
                    flat: true
                    enabled: !Services.Waydroid.loading && !Services.Waydroid.busy
                    onClicked: Services.Waydroid.refresh()

                    background: Rectangle {
                        implicitHeight: 36
                        radius: Theme.radiusMedium
                        color: refreshButton.hovered ? Theme.hover : Theme.transparent
                        border.color: Theme.border
                        border.width: 1
                    }

                    contentItem: Text {
                        text: Services.Waydroid.loading ? "…" : "\uf2f1"
                        color: refreshButton.enabled ? Theme.fg : Theme.placeholderFg
                        font.family: Services.Waydroid.loading ? Theme.fontMono : Theme.fontIcon
                        font.pixelSize: Theme.fontSizeTitle
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Text {
                width: parent.width - Theme.panelPadding * 2
                visible: Services.Waydroid.errorMessage.length > 0
                text: Services.Waydroid.errorMessage
                color: Theme.negative
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeBody
                wrapMode: Text.Wrap
            }

            Text {
                width: parent.width - Theme.panelPadding * 2
                visible: Services.Waydroid.errorMessage.length === 0 && Services.Waydroid.lastMessage.length > 0
                text: Services.Waydroid.lastMessage
                color: Theme.positive
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeBody
                wrapMode: Text.Wrap
            }

            RowLayout {
                width: parent.width - Theme.panelPadding * 2
                spacing: Theme.spacingSection

                Text {
                    text: "APPLICATIONS"
                    color: Theme.selFg
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeLabel
                    font.bold: true
                }

                Text {
                    text: Services.Waydroid.appCount
                    color: Theme.fg
                    opacity: Theme.opacitySecondary
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeSmall
                }

                Item { Layout.fillWidth: true }
            }

            TextField {
                id: appSearch
                width: parent.width - Theme.panelPadding * 2
                height: 34
                placeholderText: "Search name or package"
                placeholderTextColor: Theme.placeholderFg
                color: Theme.selFg
                selectionColor: Theme.selBg
                selectedTextColor: Theme.selFg
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeBody
                leftPadding: Theme.spacingMedium
                rightPadding: Theme.spacingMedium

                background: Rectangle {
                    color: Theme.fieldBg
                    border.color: appSearch.activeFocus ? Theme.selBg : Theme.border
                    border.width: 1
                    radius: Theme.radiusMedium
                }
            }

            Column {
                width: parent.width - Theme.panelPadding * 2
                spacing: Theme.spacingCompact

                Repeater {
                    model: root.filteredApps

                    delegate: Button {
                        id: appButton
                        required property var modelData
                        width: parent.width
                        implicitHeight: 50
                        flat: true
                        enabled: Services.Waydroid.available && !Services.Waydroid.busy
                        onClicked: {
                            Services.Waydroid.launchApp(modelData.packageName);
                            root.itemTriggered();
                        }

                        background: Rectangle {
                            color: appButton.hovered ? Theme.hover : Theme.surfaceSubtle
                            border.color: appButton.hovered ? Theme.separator : Theme.border
                            border.width: 1
                            radius: Theme.radiusMedium
                        }

                        contentItem: RowLayout {
                            spacing: Theme.spacingSection

                            Item {
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 32

                                Image {
                                    anchors.fill: parent
                                    source: appButton.modelData.icon
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    visible: source.toString().length > 0 && status !== Image.Error
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: appButton.modelData.icon.length === 0
                                    text: "\uf17b"
                                    color: Theme.fg
                                    font.family: Theme.fontIcon
                                    font.pixelSize: Theme.fontSizeDisplay
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: Theme.spacingTiny

                                Text {
                                    Layout.fillWidth: true
                                    text: appButton.modelData.name
                                    color: Theme.selFg
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeLabel
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: appButton.modelData.packageName
                                        + (appButton.modelData.hidden ? " · SYSTEM" : "")
                                    color: Theme.fg
                                    opacity: Theme.opacitySecondary
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeCaption
                                    elide: Text.ElideRight
                                }
                            }

                            Text {
                                text: "LAUNCH"
                                color: appButton.hovered ? Theme.selFg : Theme.fg
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeCaption
                                font.bold: true
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: root.filteredApps.length === 0
                    text: Services.Waydroid.appCount === 0
                        ? "No Waydroid applications have been discovered yet."
                        : "No applications match this search."
                    color: Theme.fg
                    opacity: Theme.opacitySecondary
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeBody
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    topPadding: Theme.spacingSection
                    bottomPadding: Theme.spacingSection
                }
            }

            RowLayout {
                width: parent.width - Theme.panelPadding * 2

                Text {
                    text: Services.Waydroid.vendorType.length > 0
                        ? Services.Waydroid.vendorType + " · " + Services.Waydroid.containerState
                        : Services.Waydroid.containerState
                    color: Theme.fg
                    opacity: Theme.opacitySubtle
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeCaption
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: Services.Waydroid.lastUpdated.getTime() > 0
                        ? "Updated " + Qt.formatTime(Services.Waydroid.lastUpdated, "hh:mm:ss")
                        : "Not updated"
                    color: Theme.fg
                    opacity: Theme.opacitySubtle
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeCaption
                }
            }
        }
    }
}
