pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Services.SystemTray

Item {
    id: trayRoot
    // Slot contract with windows/Bar.qml ModuleRun (see Media.qml).
    readonly property bool moduleActive: itemCount > 0
    visible: moduleActive
    implicitWidth: itemCount > 0 ? (itemCount * iconSize) + ((itemCount - 1) * iconSpacing) : 0
    implicitHeight: iconSize
    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight

    required property var rootWindow
    readonly property var trayItems: SystemTray.items && SystemTray.items.values ? SystemTray.items.values : []
    readonly property int itemCount: trayItems.length
    readonly property int iconSize: 20
    readonly property int iconSpacing: 5

    // Set to true to log every tray item's icon data to stdout (for debugging)
    property bool debugIcons: false

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: trayRoot.iconSpacing

        Repeater {
            model: trayRoot.trayItems

            delegate: IconImage {
                id: trayIcon
                required property var modelData
                width: trayRoot.iconSize
                height: trayRoot.iconSize

                // Icon resolution strategy:
                readonly property string primaryIconSource: {
                    let icon = "";
                    try { icon = modelData.icon; } catch (e) {}

                    if (icon) {
                        // Process icon path (Noctalia logic)
                        if (typeof icon === "string" && icon.includes("?path=")) {
                            const chunks = icon.split("?path=");
                            const namePart = chunks[0];
                            const pathPart = chunks[1];
                            const fileName = namePart.substring(namePart.lastIndexOf("/") + 1);
                            return `file://${pathPart}/${fileName}`;
                        }
                        return icon;
                    }

                    let iconName = "";
                    try { iconName = modelData.iconName; } catch (e) {}
                    if (iconName) return "image://icon/" + iconName;

                    // Last resort fallback
                    return "image://icon/application-x-executable";
                }

                // Fallback for apps with non-standard icons or broken DBus
                // properties (like Mullvad/Electron).
                readonly property string fallbackIconSource: {
                    const id = (modelData.id || "").toLowerCase();
                    const toolTip = (modelData.toolTip || "").toLowerCase();
                    let iconName = "";
                    try {
                        iconName = (modelData.iconName || "").toLowerCase();
                    } catch (e) {}

                    if (id.includes("vesktop") || iconName.includes("vesktop") ||
                        id.includes("discord") || iconName.includes("discord")) {
                        return "file:///usr/share/icons/hicolor/scalable/apps/vesktop.svg"
                    } else if (id.includes("mullvad") || toolTip.includes("mullvad")) {
                        return "image://icon/mullvad-vpn"
                    } else if (id.includes("telegram") || iconName.includes("telegram")) {
                        return "file:///usr/share/icons/hicolor/256x256/apps/org.telegram.desktop.png"
                    } else if (id.includes("arch-update") || iconName.includes("arch-update")) {
                        return "file:///usr/share/icons/hicolor/scalable/apps/cachy-update-blue.svg"
                    } else if (id.includes("chrome_status_icon") && toolTip.includes("connected")) {
                        // Generic Electron/Chrome ID but looks like a VPN
                        return "image://icon/network-vpn"
                    }
                    return "image://icon/application-x-executable"
                }

                // Remembering the failed primary URL keeps the fallback active
                // without assigning `source` imperatively, so later SNI icon
                // swaps still apply (and a changed URL is retried normally).
                property string failedPrimarySource: ""
                source: {
                    const primary = primaryIconSource;
                    return (primary === "" || primary === failedPrimarySource)
                        ? fallbackIconSource
                        : primary;
                }

                onStatusChanged: {
                    if (status === Image.Error && source !== fallbackIconSource)
                        failedPrimarySource = primaryIconSource;
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.LeftButton) {
                            if (!trayIcon.modelData.onlyMenu) {
                                trayIcon.modelData.activate()
                            }
                        } else if (mouse.button === Qt.MiddleButton) {
                            if (trayIcon.modelData.secondaryActivate) {
                                trayIcon.modelData.secondaryActivate()
                            }
                        } else if (mouse.button === Qt.RightButton) {
                            if (trayIcon.modelData.menu) {
                                trayRoot.rootWindow.toggleTrayMenu(trayIcon.modelData.menu, trayIcon)
                            }
                        }
                    }
                }

                Component.onDestruction: {
                    // If the SNI item vanishes while its menu is open, close
                    // the menu instead of leaving a dangling DBusMenu handle.
                    if (trayRoot.rootWindow)
                        trayRoot.rootWindow.closeTrayMenuIfAnchoredTo(trayIcon)
                }
            }
        }
    }
}
