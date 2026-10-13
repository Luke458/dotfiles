pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../services" as Services
import "."

Item {
    id: root
    implicitWidth: 560
    implicitHeight: Math.min(700, header.implicitHeight + footer.implicitHeight
        + Math.min(340, Math.max(112, shownItems.length * 84)) + 72)
    property string selectedSource: "all"
    readonly property color accent: Qt.lighter(Theme.selBg, 2.1)
    readonly property var shownItems: Services.Updates.items.filter(item =>
        (selectedSource === "all" || item.source === selectedSource)
        && item.name.toLowerCase().includes(searchField.text.trim().toLowerCase()))
    readonly property string errors: ["packages", "aur", "mise"].filter(source =>
        Services.Updates.sourceError(source) !== "").map(source =>
        sourceLabel(source) + ": " + Services.Updates.sourceError(source)).join("\n")

    function sourceLabel(source) {
        return ({packages: "Packages", aur: "AUR", mise: "mise"})[source] || source;
    }

    function openProject(url) {
        if (/^https?:\/\/[^\s]+$/.test(url))
            Quickshell.execDetached(["xdg-open", url]);
    }

    Rectangle { anchors.fill: parent; color: Theme.bgSolid; radius: Theme.radiusMedium }

    component ActionButton: StyledButton {
        property bool primary: false
        selected: primary
        bordered: true
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.sectionPadding
        spacing: Theme.spacingPanel

        ColumnLayout {
            id: header
            Layout.fillWidth: true
            spacing: Theme.spacingContent

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingSection
                IconImage {
                    source: "file:///usr/share/icons/hicolor/scalable/apps/cachy-update-blue.svg"
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingMicro
                    Text {
                        text: "UPDATES"
                        color: Theme.selFg
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.panelTitleSize
                        font.bold: true
                    }
                    Text {
                        Layout.fillWidth: true
                        text: Services.Updates.checking ? "Checking your packages and tools…"
                            : Services.Updates.hasErrors ? "Some sources could not be checked"
                            : Services.Updates.total > 0 ? Services.Updates.total + (Services.Updates.total === 1 ? " update ready to install" : " updates ready to install")
                            : "Your packages and tools are up to date"
                        color: Services.Updates.hasErrors ? Theme.negative : Theme.fg
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.panelBodySize
                        wrapMode: Text.Wrap
                    }
                }
                ActionButton {
                    text: Services.Updates.checking ? "Checking…" : "Check now"
                    enabled: !Services.Updates.checking
                    onClicked: Services.Updates.refresh()
                }
            }

            Text {
                Layout.fillWidth: true
                text: Services.Updates.lastChecked > 0
                    ? "Last checked " + Qt.formatDateTime(new Date(Services.Updates.lastChecked * 1000), "ddd, h:mm AP")
                        + (Services.Updates.nextCheck.getTime() > 0 && !Services.Updates.checking
                            ? "   ·   Next check " + Qt.formatTime(Services.Updates.nextCheck, "h:mm AP") : "")
                    : "Automatic checks every 30 minutes"
                color: Theme.fg
                font.family: Theme.fontMono
                font.pixelSize: Theme.panelCaptionSize
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingCompact
                Repeater {
                    model: [{key: "all", title: "All"}, {key: "packages", title: "Packages"},
                        {key: "aur", title: "AUR"}, {key: "mise", title: "mise"}]
                    delegate: ActionButton {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        primary: root.selectedSource === modelData.key
                        text: modelData.title + "  " + (modelData.key === "all"
                            ? Services.Updates.total : Services.Updates.count(modelData.key))
                        onClicked: root.selectedSource = modelData.key
                    }
                }
            }

            StyledTextField {
                id: searchField
                Layout.fillWidth: true

                placeholderText: "Search packages and tools"

            }

            Text {
                Layout.fillWidth: true
                visible: root.errors !== ""
                text: root.errors + "\nPrevious results are shown where available."
                color: Theme.negative
                wrapMode: Text.Wrap
                font.family: Theme.fontMono
                font.pixelSize: Theme.panelBodySize
                maximumLineCount: 5
                elide: Text.ElideRight
                ToolTip.visible: errorHover.hovered
                ToolTip.text: root.errors
                HoverHandler { id: errorHover }
            }
        }

        ListView {
            id: packageList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 8
            model: root.shownItems
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            delegate: Rectangle {
                id: packageRow
                required property var modelData
                activeFocusOnTab: Boolean(modelData.url)
                Accessible.role: Accessible.Link
                Accessible.name: modelData.name + " project page"
                Keys.onReturnPressed: root.openProject(modelData.url)
                Keys.onSpacePressed: root.openProject(modelData.url)
                width: packageList.width
                height: 76
                color: linkArea.containsMouse && modelData.url ? Theme.hover : Theme.surfaceSubtle
                border.width: 1
                border.color: activeFocus ? Theme.selBg : (linkArea.containsMouse && modelData.url ? Theme.separator : Theme.border)
                radius: Theme.radiusMedium

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Text {
                            Layout.fillWidth: true
                            text: packageRow.modelData.name
                            color: Theme.selFg
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.panelBodySize
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            text: root.sourceLabel(packageRow.modelData.source)
                            color: Theme.fg
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.panelCaptionSize
                        }
                        Text {
                            visible: !!packageRow.modelData.url
                            text: "\uf08e"
                            color: root.accent
                            font.family: Theme.fontIcon
                            font.pixelSize: Theme.fontSizeLabel
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 3
                            text: packageRow.modelData.current || "Not installed"
                            color: Theme.fg
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.panelBodySize
                            elide: Text.ElideMiddle
                        }
                        Text { text: "→"; color: Theme.fg; font.pixelSize: Theme.panelBodySize }
                        Text {
                            Layout.fillWidth: true
                            Layout.preferredWidth: 2
                            text: packageRow.modelData.latest || "Latest"
                            color: Theme.positive
                            font.family: Theme.fontMono
                            font.pixelSize: Theme.panelBodySize
                            elide: Text.ElideMiddle
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
                MouseArea {
                    id: linkArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: packageRow.modelData.url ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.openProject(packageRow.modelData.url)
                }
                ToolTip.visible: linkArea.containsMouse
                ToolTip.delay: 600
                ToolTip.text: packageRow.modelData.name + "\n"
                    + (packageRow.modelData.current || "Not installed") + " → " + packageRow.modelData.latest
                    + (packageRow.modelData.url ? "\nOpen project: " + packageRow.modelData.url : "")
            }

            Column {
                anchors.centerIn: parent
                width: parent.width - 32
                spacing: 7
                visible: root.shownItems.length === 0
                Text {
                    width: parent.width
                    text: searchField.text.trim() ? "No matching packages"
                        : Services.Updates.checking ? "Checking for updates…"
                        : Services.Updates.hasErrors ? "Check incomplete"
                        : "All clear"
                    color: Theme.selFg
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.panelTitleSize
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    width: parent.width
                    text: searchField.text.trim() ? "Try another name or select a different source."
                        : Services.Updates.hasErrors ? "Check the source messages above and try again."
                        : Services.Updates.checking ? "Results will appear here shortly."
                        : "No pending updates in this view."
                    color: Theme.fg
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.panelBodySize
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        ColumnLayout {
            id: footer
            Layout.fillWidth: true
            spacing: Theme.spacingSection
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.border }
            Text {
                Layout.fillWidth: true
                visible: Services.Updates.actionError !== "" || Services.Updates.lastAction !== ""
                text: Services.Updates.actionError || "Opened "
                    + ({pacman: "Pacman", cachy: "Cachy Update", mise: "mise", all: "both updaters"}[Services.Updates.lastAction] || "updater")
                    + " in kitty"
                color: Services.Updates.actionError ? Theme.negative : Theme.positive
                font.family: Theme.fontMono
                font.pixelSize: Theme.panelBodySize
                wrapMode: Text.Wrap
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                enabled: !Services.Updates.launching
                ActionButton {
                    text: "Pacman only"
                    Accessible.description: "Upgrade repository packages without updating AUR packages"
                    ToolTip.visible: hovered
                    ToolTip.text: "Repository packages only · sudo pacman -Syu"
                    onClicked: Services.Updates.launch("pacman")
                }
                ActionButton { text: "Cachy Update"; onClicked: Services.Updates.launch("cachy") }
                ActionButton { text: "Upgrade mise"; onClicked: Services.Updates.launch("mise") }
                Item { Layout.fillWidth: true }
                ActionButton { text: "Update all"; primary: true; onClicked: Services.Updates.launch("all") }
            }
            Text {
                text: "Updates open in a terminal for review."
                color: Theme.fg
                font.family: Theme.fontMono
                font.pixelSize: Theme.panelCaptionSize
            }
        }
    }
}
