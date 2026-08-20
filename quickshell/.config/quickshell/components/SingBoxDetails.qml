pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../services" as Services
import "."

Item {
    id: root

    property string selectedRoute: "bypass"

    implicitWidth: 560
    implicitHeight: 620

    Component.onCompleted: {
        Services.SingBox.beginDetails();
        if (Services.SingBox.routes.length > 0
                && !root.hasRoute(root.selectedRoute))
            root.selectedRoute = Services.SingBox.routes[0].name;
    }
    Component.onDestruction: Services.SingBox.endDetails()

    function hasRoute(name) {
        for (let i = 0; i < Services.SingBox.routes.length; i++) {
            if (Services.SingBox.routes[i].name === name)
                return true;
        }
        return false;
    }

    function addCurrentEntry() {
        if (Services.SingBox.busy)
            return;
        const value = entryField.text.trim();
        if (value.length === 0)
            return;
        Services.SingBox.addEntry(root.selectedRoute, value);
        entryField.clear();
    }

    function statusColor() {
        if (!Services.SingBox.active)
            return Theme.negative;
        if (!Services.SingBox.liveSynchronized
                || !Services.SingBox.deploymentSynchronized)
            return Theme.yellow;
        return Theme.positive;
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
                    text: "\u{f0ac}"
                    color: root.statusColor()
                    font.family: Theme.fontIcon
                    font.pixelSize: Theme.fontSizeValueSmall
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingTiny

                    Text {
                        text: "SING-BOX ROUTES"
                        color: Theme.selFg
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeHeadingLarge
                        font.bold: true
                    }

                    Text {
                        text: "MAIN " + Services.SingBox.mainServiceState.toUpperCase()
                            + " · BYPASS " + Services.SingBox.bypassServiceState.toUpperCase()
                            + " · " + Services.SingBox.total + " entries"
                        color: Theme.fg
                        opacity: Theme.opacityStrong
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeBody
                    }
                }

                MouseArea {
                    id: refreshButton
                    implicitWidth: refreshIcon.implicitWidth + Theme.controlPadding
                    implicitHeight: 28
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !Services.SingBox.loading && !Services.SingBox.busy
                    onClicked: Services.SingBox.refresh()

                    Rectangle {
                        anchors.fill: parent
                        color: refreshButton.containsMouse ? Theme.hover : Theme.transparent
                        border.color: Theme.border
                        border.width: 1
                        radius: Theme.radiusMedium
                    }

                    Text {
                        id: refreshIcon
                        anchors.centerIn: parent
                        text: Services.SingBox.loading ? "…" : "\u{f0450}"
                        color: refreshButton.enabled ? Theme.fg : Theme.placeholderFg
                        font.family: Services.SingBox.loading ? Theme.fontMono : Theme.fontIcon
                        font.pixelSize: Theme.fontSizeTitle
                    }
                }
            }

            Rectangle {
                width: parent.width - Theme.panelPadding * 2
                height: 1
                color: Theme.separator
            }

            Column {
                width: parent.width - Theme.panelPadding * 2
                spacing: Theme.spacingComfortable

                Text {
                    text: "ADD DOMAIN OR RULE"
                    color: Theme.selFg
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeLabel
                    font.bold: true
                }

                Row {
                    width: parent.width
                    spacing: Theme.spacingComfortable

                    Repeater {
                        model: Services.SingBox.routes

                        delegate: MouseArea {
                            id: routeChoice
                            required property var modelData
                            implicitWidth: routeChoiceLabel.implicitWidth + Theme.sectionPadding
                            implicitHeight: 28
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !Services.SingBox.busy
                            onClicked: root.selectedRoute = modelData.name

                            Rectangle {
                                anchors.fill: parent
                                color: root.selectedRoute === routeChoice.modelData.name
                                    ? Theme.selectionMedium
                                    : (routeChoice.containsMouse ? Theme.hover : Theme.surfaceSubtle)
                                border.color: root.selectedRoute === routeChoice.modelData.name
                                    ? Theme.selBg : Theme.border
                                border.width: 1
                                radius: Theme.radiusMedium
                            }

                            Text {
                                id: routeChoiceLabel
                                anchors.centerIn: parent
                                text: Services.SingBox.routeLabel(routeChoice.modelData.name)
                                color: root.selectedRoute === routeChoice.modelData.name
                                    ? Theme.selFg : Theme.fg
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: root.selectedRoute === routeChoice.modelData.name
                            }
                        }
                    }
                }

                RowLayout {
                    width: parent.width
                    spacing: Theme.spacingComfortable

                    TextField {
                        id: entryField
                        Layout.fillWidth: true
                        implicitHeight: 32
                        enabled: !Services.SingBox.busy
                        placeholderText: "example.com or https://example.com/path"
                        color: Theme.selFg
                        placeholderTextColor: Theme.placeholderFg
                        selectionColor: Theme.selBg
                        selectedTextColor: Theme.selFg
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeBody
                        leftPadding: Theme.controlPadding
                        rightPadding: Theme.controlPadding
                        onAccepted: root.addCurrentEntry()

                        background: Rectangle {
                            color: Theme.fieldBg
                            border.color: entryField.activeFocus ? Theme.selBg : Theme.border
                            border.width: 1
                            radius: Theme.radiusMedium
                        }
                    }

                    MouseArea {
                        id: addButton
                        implicitWidth: addLabel.implicitWidth + Theme.sectionPadding
                        implicitHeight: 32
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !Services.SingBox.busy && entryField.text.trim().length > 0
                        onClicked: root.addCurrentEntry()

                        Rectangle {
                            anchors.fill: parent
                            color: addButton.containsMouse && addButton.enabled ? Theme.hover : Theme.surfaceSubtle
                            border.color: addButton.enabled ? Theme.selBg : Theme.border
                            border.width: 1
                            radius: Theme.radiusMedium
                        }

                        Text {
                            id: addLabel
                            anchors.centerIn: parent
                            text: Services.SingBox.busy ? "WORKING…" : "ADD"
                            color: addButton.enabled ? Theme.selFg : Theme.placeholderFg
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                        }
                    }
                }

                Text {
                    width: parent.width
                    text: "Bare domains include subdomains. Prefix with =, keyword:, regex:, or ip: for other match types."
                    color: Theme.fg
                    opacity: Theme.opacitySecondary
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeCaption
                    wrapMode: Text.Wrap
                }
            }

            Text {
                width: parent.width - Theme.panelPadding * 2
                visible: Services.SingBox.errorMessage.length > 0
                text: Services.SingBox.errorMessage
                color: Theme.negative
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeBody
                wrapMode: Text.Wrap
            }

            Text {
                width: parent.width - Theme.panelPadding * 2
                visible: Services.SingBox.errorMessage.length === 0
                    && Services.SingBox.lastMessage.length > 0
                text: Services.SingBox.lastMessage
                color: Theme.positive
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeBody
                wrapMode: Text.Wrap
            }

            Column {
                width: parent.width - Theme.panelPadding * 2
                spacing: Theme.spacingComfortable

                Repeater {
                    model: Services.SingBox.routes

                    delegate: Rectangle {
                        id: routeCard
                        required property var modelData
                        width: parent.width
                        implicitHeight: routeContents.implicitHeight + Theme.sectionPadding * 2
                        color: Theme.surfaceSubtle
                        border.color: Theme.border
                        border.width: 1
                        radius: Theme.radiusMedium

                        Column {
                            id: routeContents
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Theme.spacingSection
                            spacing: Theme.spacingComfortable

                            RowLayout {
                                width: parent.width

                                Text {
                                    text: Services.SingBox.routeLabel(routeCard.modelData.name)
                                    color: Theme.selFg
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeLabel
                                    font.bold: true
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: routeCard.modelData.count + (routeCard.modelData.count === 1 ? " ENTRY" : " ENTRIES")
                                    color: Theme.fg
                                    opacity: Theme.opacityStrong
                                    font.family: Theme.fontMono
                                    font.pixelSize: Theme.fontSizeCaption
                                }
                            }

                            Text {
                                visible: routeCard.modelData.entries.length === 0
                                text: "No entries"
                                color: Theme.fg
                                opacity: Theme.opacityMedium
                                font.family: Theme.fontMono
                                font.pixelSize: Theme.fontSizeBody
                            }

                            Repeater {
                                model: routeCard.modelData.entries

                                delegate: Rectangle {
                                    id: entryRow
                                    required property var modelData
                                    width: parent.width
                                    height: 34
                                    color: Theme.fieldBg
                                    radius: Theme.radiusSmall

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: Theme.spacingMedium
                                        anchors.rightMargin: Theme.spacingSmall
                                        spacing: Theme.spacingComfortable

                                        Text {
                                            Layout.fillWidth: true
                                            text: entryRow.modelData.line
                                            color: Theme.selFg
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontSizeBody
                                            elide: Text.ElideMiddle
                                        }

                                        Text {
                                            text: String(entryRow.modelData.field || "").replace("domain_", "").toUpperCase()
                                            color: Theme.fg
                                            opacity: Theme.opacityMedium
                                            font.family: Theme.fontMono
                                            font.pixelSize: Theme.fontSizeCaption
                                        }

                                        MouseArea {
                                            id: removeButton
                                            implicitWidth: 26
                                            implicitHeight: 26
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            enabled: !Services.SingBox.busy
                                            onClicked: Services.SingBox.removeEntry(
                                                routeCard.modelData.name,
                                                entryRow.modelData.line)

                                            Rectangle {
                                                anchors.fill: parent
                                                color: removeButton.containsMouse ? Theme.negativeSurface : Theme.transparent
                                                radius: Theme.radiusMedium
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "×"
                                                color: removeButton.containsMouse ? Theme.negative : Theme.fg
                                                font.family: Theme.fontMono
                                                font.pixelSize: Theme.fontSizeTitle
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                width: parent.width - Theme.panelPadding * 2
                spacing: Theme.spacingComfortable

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingTiny

                    Text {
                        text: Services.SingBox.liveSynchronized
                            ? "SOURCE AND LIVE RULE SETS MATCH"
                            : "LIVE RULE SETS NEED APPLY"
                        color: Services.SingBox.liveSynchronized ? Theme.positive : Theme.yellow
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeCaption
                        font.bold: true
                    }

                    Text {
                        text: Services.SingBox.deploymentSynchronized
                            ? "CONFIG AND SERVICE FILES MATCH"
                            : "CONFIG OR SERVICE FILES NEED INSTALL"
                        color: Services.SingBox.deploymentSynchronized
                            ? Theme.positive : Theme.yellow
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeCaption
                        font.bold: true
                    }

                    Text {
                        text: Services.SingBox.liveWritable
                            ? "Edits validate and sync immediately"
                            : "Live directory is not writable; run sbr install once"
                        color: Theme.fg
                        opacity: Theme.opacitySecondary
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeCaption
                    }
                }

                MouseArea {
                    id: applyButton
                    implicitWidth: applyLabel.implicitWidth + Theme.sectionPadding
                    implicitHeight: 30
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !Services.SingBox.busy
                    onClicked: Services.SingBox.validateAndApply()

                    Rectangle {
                        anchors.fill: parent
                        color: applyButton.containsMouse ? Theme.hover : Theme.surfaceSubtle
                        border.color: Theme.border
                        border.width: 1
                        radius: Theme.radiusMedium
                    }

                    Text {
                        id: applyLabel
                        anchors.centerIn: parent
                        text: Services.SingBox.busy ? Services.SingBox.actionName.toUpperCase() : "VALIDATE & APPLY"
                        color: applyButton.enabled ? Theme.selFg : Theme.placeholderFg
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                    }
                }
            }

            Text {
                width: parent.width - Theme.panelPadding * 2
                text: Services.SingBox.sourceDir
                color: Theme.fg
                opacity: Theme.opacitySubtle
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeCaption
                elide: Text.ElideMiddle
            }
        }
    }
}
