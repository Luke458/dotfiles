pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import Quickshell.Services.SystemTray

Item {
    id: trayRoot
    visible: itemCount > 0
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
                source: {
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
                    return "image://icon/application-x-executable"
                }

                onStatusChanged: {
                    if (status === Image.Error) {
                        const id = (modelData.id || "").toLowerCase();
                        const toolTip = (modelData.toolTip || "").toLowerCase();
                        let iconName = "";
                        try {
                            iconName = (modelData.iconName || "").toLowerCase();
                        } catch (e) {}

                        // Fallback for apps with non-standard icons or broken DBus properties (like Mullvad/Electron)
                        if (id.includes("vesktop") || iconName.includes("vesktop") ||
                            id.includes("discord") || iconName.includes("discord")) {
                            source = "file:///usr/share/icons/hicolor/scalable/apps/vesktop.svg"
                        } else if (id.includes("mullvad") || toolTip.includes("mullvad")) {
                            source = "image://icon/mullvad-vpn"
                        } else if (id.includes("telegram") || iconName.includes("telegram")) {
                            source = "file:///usr/share/icons/hicolor/256x256/apps/org.telegram.desktop.png"
                        } else if (id.includes("arch-update") || iconName.includes("arch-update")) {
                            source = "file:///usr/share/icons/hicolor/scalable/apps/cachy-update-blue.svg"
                        } else if (id.includes("chrome_status_icon") && toolTip.includes("connected")) {
                            // Generic Electron/Chrome ID but looks like a VPN
                            source = "image://icon/network-vpn"
                        } else {
                            source = "image://icon/application-x-executable"
                        }
                    }
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
            }
        }
    }
}
