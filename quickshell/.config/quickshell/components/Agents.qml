pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../services"
import "."

// One bar icon for every AI coding subscription. The mark and the readout
// follow the selected provider; middle click cycles subscriptions, right
// click launches the agent CLI. Hidden until some provider has data.
Item {
    id: root

    property bool forceHovered: false
    readonly property bool hovered: forceHovered || clickArea.containsMouse
    readonly property var provider: AgentsUsage.currentProvider
    readonly property var bindingLimit: AgentsUsage.bindingWindow(provider)
    readonly property var balance: provider ? provider.balance : null

    readonly property bool alarming: (!!bindingLimit && bindingLimit.percent >= 0.9)
        || (!!balance && balance.funded > 0 && balance.remaining / balance.funded <= 0.1)

    readonly property color statusColor: {
        if (!provider)
            return Theme.fg;
        if (alarming)
            return Theme.negative;
        if (bindingLimit) {
            if (bindingLimit.percent >= 0.7)
                return Theme.yellow;
        }
        return Theme.fg;
    }

    // ModuleRun hides modules that expose moduleActive === false.
    readonly property bool moduleActive: AgentsUsage.hasProviders
    visible: moduleActive

    implicitWidth: layout.implicitWidth + Theme.controlPadding
    implicitHeight: 24

    signal clicked()
    signal cycleRequested()
    signal launchRequested()

    function iconSource() {
        if (!provider)
            return "";
        return Qt.resolvedUrl("../assets/agents/" + provider.providerId + ".svg");
    }

    function readout() {
        if (bindingLimit && bindingLimit.percent >= 0)
            return Math.round(bindingLimit.percent * 100) + "%";
        if (balance)
            return Math.round(balance.remaining) + "";
        if (provider && provider.loading)
            return "...";
        return "--";
    }

    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: Theme.spacingSmall

        Image {
            id: providerMark
            source: root.iconSource()
            sourceSize.width: 36
            sourceSize.height: 36
            Layout.preferredWidth: 18
            Layout.preferredHeight: 18
            fillMode: Image.PreserveAspectFit
            visible: source !== "" && status !== Image.Error
        }

        Text {
            visible: !providerMark.visible
            text: "\u{f121}"
            color: root.hovered ? Theme.selFg : root.statusColor
            font.family: Theme.fontIcon
            font.pixelSize: Theme.fontSizeTitle
        }

        Text {
            text: root.readout()
            color: root.hovered ? Theme.selFg : root.statusColor
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSizeBar
            font.bold: root.alarming
        }
    }

    MouseArea {
        id: clickArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                root.launchRequested();
            } else if (mouse.button === Qt.MiddleButton) {
                root.cycleRequested();
            } else {
                AgentsUsage.refreshLimits();
                root.clicked();
            }
        }
    }
}
