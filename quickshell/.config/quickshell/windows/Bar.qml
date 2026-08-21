pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../components" as Components
import "../services"

PanelWindow { // qmllint disable uncreatable-type
    id: window

    property bool inhibited: false
    property bool leftSectionExpanded: false
    property bool focused: screen && Hyprland.focusedMonitor && screen.name === Hyprland.focusedMonitor.name
    property bool isHidden: OverlayController.opened && OverlayController.targetScreenName === (screen ? screen.name : "")
    property list<Component> expandableModules: [trayModule, mediaModule, sunsetModule, idleModule, mullvadModule, singBoxModule, podmanModule, waydroidModule]
    property list<Component> primaryModules: [attackSharkModule, codexModule, btcModule, weatherModule, volumeModule, cpuModule, gpuModule, memoryModule, diskModule, dateModule, clockModule, notificationModule, powerModule]

    signal toggleInhibitor
    signal toggleLeftSection

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 24
    color: isHidden ? Components.Theme.transparent : Components.Theme.bg
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.exclusiveZone: 24
    WlrLayershell.namespace: "qs-bar"

    HoverHandler { id: barHoverHandler }

    Components.ScreenMoveRemap {
        id: remapGuard
        window: window
    }
    visible: !remapGuard.remapping

    Behavior on color {
        ColorAnimation { duration: 250; easing.type: Easing.OutCubic }
    }

    onIsHiddenChanged: {
        if (isHidden) {
            dynamicFlyout.close();
            trayMenuOverlay.visible = false;
        }
    }

    function popupAnchorHovered(item) {
        return dynamicFlyout.visible && dynamicFlyout.anchorItem === item && dynamicFlyout.anchorContainsPointer;
    }

    function toggleFlyout(path, anchorItem, properties) {
        dynamicFlyout.toggle(Qt.resolvedUrl("../components/" + path), anchorItem, properties || ({}));
    }

    function togglePowerMenu() {
        dynamicFlyout.close();
        OverlayController.togglePicker("power", "{}");
    }

    function toggleTrayMenu(menuHandle, anchorItem) {
        dynamicFlyout.close();
        trayMenuOverlay.toggle(menuHandle, anchorItem, window.screen);
    }

    function closeTrayMenuIfAnchoredTo(item) {
        if (trayMenuOverlay.anchorItem === item)
            trayMenuOverlay.close();
    }

    component ModuleRun: Row {
        id: moduleRun
        required property var modules
        spacing: Components.Theme.spacingSmall
        height: 24

        Repeater {
            model: moduleRun.modules
            delegate: Row {
                id: moduleEntry
                required property int index
                required property var modelData
                height: 24
                spacing: Components.Theme.spacingSmall

                Loader {
                    id: moduleLoader
                    anchors.verticalCenter: parent.verticalCenter
                    sourceComponent: moduleEntry.modelData
                }

                Components.Separator {
                    visible: moduleEntry.index < moduleRun.modules.length - 1
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    Component {
        id: trayModule
        Components.Tray { rootWindow: window }
    }

    Component {
        id: mediaModule
        Components.Media {
            id: item
            visible: Media.hasMedia
            onItemTriggered: window.toggleFlyout("MediaDetails.qml", item)
        }
    }

    Component {
        id: sunsetModule
        Components.Hyprsunset {
            id: item
            hyprsunset: Hyprsunset
            forceHovered: window.popupAnchorHovered(item)
            onItemTriggered: window.toggleFlyout("HyprsunsetDetails.qml", item, { hyprsunset: Hyprsunset })
        }
    }

    Component {
        id: idleModule
        Components.IdleInhibitorWidget {
            inhibited: window.inhibited
            onToggle: window.toggleInhibitor()
        }
    }

    Component {
        id: mullvadModule
        Components.MullvadIndicator {
            id: item
            forceHovered: window.popupAnchorHovered(item)
            onItemTriggered: window.toggleFlyout("MullvadDetails.qml", item)
        }
    }

    Component {
        id: podmanModule
        Components.PodmanQuadletIndicator {
            id: item
            forceHovered: window.popupAnchorHovered(item)
            onClicked: window.toggleFlyout("PodmanQuadletsDetails.qml", item)
        }
    }

    Component {
        id: singBoxModule
        Components.SingBoxIndicator {
            id: item
            forceHovered: window.popupAnchorHovered(item)
            onClicked: window.toggleFlyout("SingBoxDetails.qml", item)
        }
    }

    Component {
        id: waydroidModule
        Components.WaydroidIndicator {
            id: item
            forceHovered: window.popupAnchorHovered(item)
            onClicked: window.toggleFlyout("WaydroidDetails.qml", item)
        }
    }

    Component { id: attackSharkModule; Components.AttackSharkBattery {} }

    Component {
        id: codexModule
        Components.CodexUsage {
            id: item
            forceHovered: window.popupAnchorHovered(item)
            onClicked: window.toggleFlyout("CodexUsageDetails.qml", item)
        }
    }

    Component {
        id: btcModule
        Components.BtcTicker {
            id: item
            forceHovered: window.popupAnchorHovered(item)
            onClicked: window.toggleFlyout("BtcDetails.qml", item)
        }
    }

    Component {
        id: weatherModule
        Components.Weather {
            id: item
            forceHovered: window.popupAnchorHovered(item)
            onClicked: window.toggleFlyout("AdvancedWeatherDetails.qml", item)
        }
    }

    Component {
        id: volumeModule
        Components.VolumeWidget {
            id: item
            forceHovered: window.popupAnchorHovered(item)
            onItemTriggered: window.toggleFlyout("VolumeMixerDetails.qml", item)
        }
    }

    Component {
        id: cpuModule
        Components.Cpu {
            id: item
            forceHovered: window.popupAnchorHovered(item)
            onClicked: window.toggleFlyout("CpuDetails.qml", item)
        }
    }

    Component {
        id: gpuModule
        Components.Gpu {
            id: item
            forceHovered: window.popupAnchorHovered(item)
            onClicked: window.toggleFlyout("GpuDetails.qml", item)
        }
    }

    Component {
        id: memoryModule
        Components.Memory {
            id: item
            forceHovered: window.popupAnchorHovered(item)
            onClicked: window.toggleFlyout("MemoryDetails.qml", item)
        }
    }

    Component {
        id: diskModule
        Components.Disk {
            id: item
            forceHovered: window.popupAnchorHovered(item)
            onClicked: window.toggleFlyout("DiskDetails.qml", item)
        }
    }

    Component {
        id: dateModule
        Components.DateWidget {
            id: item
            forceHovered: window.popupAnchorHovered(item)
            onClicked: window.toggleFlyout("CalendarDetails.qml", item)
        }
    }

    Component {
        id: clockModule
        Components.Clock {
            id: item
            forceHovered: window.popupAnchorHovered(item)
            onClicked: window.toggleFlyout("ClockDetails.qml", item)
        }
    }

    Component {
        id: notificationModule
        MouseArea {
            id: item
            property bool hovered: containsMouse || window.popupAnchorHovered(item)
            implicitWidth: notificationLayout.implicitWidth + 10
            implicitHeight: 24
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            RowLayout {
                id: notificationLayout
                anchors.centerIn: parent
                spacing: Components.Theme.spacingSmall
                Text {
                    text: Notifications.doNotDisturb ? "\u{f1f6}" : (Notifications.unreadCount > 0 ? "\u{f0f3}" : "\u{eaa2}")
                    font.family: Components.Theme.fontIcon
                    font.pixelSize: Components.Theme.fontSizeTitle
                    color: item.hovered ? Components.Theme.selBg : Components.Theme.fg
                }
                Text {
                    text: Notifications.unreadCount
                    visible: Notifications.unreadCount > 0
                    color: item.hovered ? Components.Theme.selBg : Components.Theme.fg
                    font.pixelSize: Components.Theme.fontSizeBody
                    font.family: Components.Theme.fontMono
                    font.bold: true
                }
            }

            onClicked: {
                window.toggleFlyout("NotificationCenter.qml", item);
                Notifications.markAllAsRead();
            }
        }
    }

    Component {
        id: powerModule
        MouseArea {
            id: item
            implicitWidth: 24
            implicitHeight: 24
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            Text {
                anchors.centerIn: parent
                text: "\u{f0425}"
                font.family: Components.Theme.fontIcon
                font.pixelSize: Components.Theme.fontSizeTitle
                color: item.containsMouse ? Components.Theme.red : Components.Theme.fg
            }
            onClicked: window.togglePowerMenu()
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.rightMargin: Components.Theme.controlPadding
        spacing: Components.Theme.spacingSmall
        opacity: window.isHidden ? 0 : 1

        Behavior on opacity {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        Components.Workspaces {
            Layout.alignment: Qt.AlignLeft
            monitorName: window.screen ? window.screen.name : ""
        }
        Components.SpecialWorkspaceIndicator {
            Layout.alignment: Qt.AlignLeft
            screen: window.screen
        }
        Components.LayoutIndicator { Layout.alignment: Qt.AlignLeft }
        Components.WindowTitle {
            Layout.fillWidth: true
            active: window.focused
        }

        RowLayout {
            visible: window.focused
            spacing: Components.Theme.spacingSmall

            Item {
                id: expandableGroup
                property real expandedWidth: expandedRun.implicitWidth
                property real shownWidth: window.leftSectionExpanded ? expandedWidth : 0
                implicitWidth: shownWidth
                implicitHeight: 24
                clip: true
                Layout.preferredWidth: implicitWidth
                Layout.minimumWidth: implicitWidth
                Layout.maximumWidth: implicitWidth
                Layout.preferredHeight: implicitHeight
                Behavior on shownWidth {
                    NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
                }
                ModuleRun {
                    id: expandedRun
                    modules: window.expandableModules
                }
            }

            MouseArea {
                id: expandButton
                implicitWidth: expandText.implicitWidth + 10
                implicitHeight: 24
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                Text {
                    id: expandText
                    anchors.centerIn: parent
                    text: window.leftSectionExpanded ? ">" : "<"
                    color: expandButton.containsMouse ? Components.Theme.selBg : Components.Theme.fg
                    font.pixelSize: Components.Theme.fontSizeBar
                    font.family: Components.Theme.fontMono
                    font.bold: true
                }
                onClicked: window.toggleLeftSection()
            }

            Components.Separator {}
            ModuleRun { modules: window.primaryModules }
        }
    }

    Components.TrayMenuOverlay {
        id: trayMenuOverlay
        visible: false
        monitor: window.screen
        anchorWindow: window
    }

    Components.ShellPopup {
        id: dynamicFlyout
        visible: false
        anchorWindow: window
        isAnchorHovered: {
            if (!anchorItem || !barHoverHandler.hovered)
                return false;
            const point = barHoverHandler.point.position;
            const pos = anchorItem.mapToItem(null, 0, 0);
            return point.x >= pos.x && point.x <= pos.x + anchorItem.width
                && point.y >= pos.y && point.y <= pos.y + anchorItem.height;
        }
    }
}
