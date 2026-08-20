pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "." as Components

Item {
    id: root
    property var menuHandle: null
    property var activeSubMenuEntry: null
    property var activeSubMenuItem: null
    property var popupWindow: null
    property var parentMenu: null
    property var monitor: null
    property bool isSubMenu: false
    property bool usePopupSubmenus: popupWindow !== null
    property bool childMenuContainsMouse: false
    property int hoveredRowCount: 0
    property int maxMenuHeight: 360
    property int menuWidth: 200
    property int outerPadding: Theme.popupPadding
    property int itemPadding: Theme.spacingComfortable
    readonly property bool containsMenuMouse: backgroundHover.hovered || hoveredRowCount > 0 || childMenuContainsMouse
    
    // Signal to notify parent to close the flyout
    signal itemTriggered()
    signal requestClose()

    implicitWidth: subMenu.width + outerPadding * 2
    implicitHeight: subMenu.height + outerPadding * 2

    function closeSubMenu() {
        submenuWindow.visible = false
        submenuLoader.source = ""
        inlineSubmenuLoader.source = ""
        activeSubMenuEntry = null
        activeSubMenuItem = null
        childMenuContainsMouse = false
    }

    function showSubMenu(menuEntry, sourceItem) {
        if (activeSubMenuEntry === menuEntry) {
            return
        }

        closeSubMenu()
        activeSubMenuEntry = menuEntry
        activeSubMenuItem = sourceItem
        const properties = {
            menuHandle: menuEntry,
            isSubMenu: true,
            monitor: root.monitor,
            popupWindow: root.usePopupSubmenus ? submenuWindow : null,
            usePopupSubmenus: root.usePopupSubmenus,
            parentMenu: root
        }

        if (root.usePopupSubmenus) {
            submenuLoader.setSource(Qt.resolvedUrl("TrayMenu.qml"), properties)
        } else {
            inlineSubmenuLoader.setSource(Qt.resolvedUrl("TrayMenu.qml"), properties)
        }
    }

    function subMenuEntryY(sourceItem) {
        return sourceItem ? subMenu.y + sourceItem.y - menuFlickable.contentY : subMenu.y
    }

    function forceClose() {
        var p = root.parent
        while (p) {
            if (p.objectName === "shell-popup-window" || p.WlrLayershell !== undefined) { // qmllint disable missing-property
                p.visible = false
            }
            p = p.parent
        }
        root.requestClose()
    }

    onMenuHandleChanged: closeSubMenu()
    Component.onDestruction: closeSubMenu()
    onContainsMenuMouseChanged: {
        if (parentMenu) {
            parentMenu.childMenuContainsMouse = containsMenuMouse
        }

        if (containsMenuMouse) {
            closeSubMenuTimer.stop()
        } else if (activeSubMenuEntry !== null) {
            closeSubMenuTimer.restart()
        }
    }

    Timer {
        id: closeSubMenuTimer
        interval: 650
        repeat: false
        onTriggered: {
            if (!root.containsMenuMouse) {
                root.closeSubMenu()
            }
        }
    }

    PopupWindow {
        id: submenuWindow
        visible: false
        anchor.window: root.popupWindow
        anchor.rect.x: root.implicitWidth - 1
        anchor.rect.y: root.subMenuEntryY(root.activeSubMenuItem)
        implicitWidth: submenuLoader.item ? submenuLoader.item.implicitWidth : 1 // qmllint disable missing-property
        implicitHeight: submenuLoader.item ? submenuLoader.item.implicitHeight : 1 // qmllint disable missing-property
        color: Theme.transparent
        grabFocus: false

        Loader {
            id: submenuLoader
            anchors.fill: parent

            onLoaded: { // qmllint disable missing-property
                if (item.requestClose !== undefined) { // qmllint disable missing-property
                    item.requestClose.connect(() => root.requestClose()) // qmllint disable missing-property
                }
                if (item.itemTriggered !== undefined) { // qmllint disable missing-property
                    item.itemTriggered.connect(() => root.itemTriggered()) // qmllint disable missing-property
                }
                if (item.containsMenuMouseChanged !== undefined) { // qmllint disable missing-property
                    item.containsMenuMouseChanged.connect(() => { // qmllint disable missing-property
                        root.childMenuContainsMouse = item.containsMenuMouse // qmllint disable missing-property
                    })
                }
                root.childMenuContainsMouse = item.containsMenuMouse // qmllint disable missing-property
                submenuWindow.visible = true
            }
        }
    }

    Loader {
        id: inlineSubmenuLoader
        x: root.implicitWidth - 1
        y: root.subMenuEntryY(root.activeSubMenuItem)
        z: 20

        onLoaded: { // qmllint disable missing-property
            if (item.requestClose !== undefined) { // qmllint disable missing-property
                item.requestClose.connect(() => root.requestClose()) // qmllint disable missing-property
            }
            if (item.itemTriggered !== undefined) { // qmllint disable missing-property
                item.itemTriggered.connect(() => root.itemTriggered()) // qmllint disable missing-property
            }
            if (item.containsMenuMouseChanged !== undefined) { // qmllint disable missing-property
                item.containsMenuMouseChanged.connect(() => { // qmllint disable missing-property
                    root.childMenuContainsMouse = item.containsMenuMouse // qmllint disable missing-property
                })
            }
            root.childMenuContainsMouse = item.containsMenuMouse // qmllint disable missing-property
        }
    }

    // Visual background for the menu (required for submenus)
    Rectangle {
        anchors.fill: parent
        visible: root.isSubMenu
        color: Components.Theme.bg
        border.color: Components.Theme.border
        border.width: 1
        radius: Theme.radiusNone

        HoverHandler {
            id: backgroundHover
        }
        
        // Ensure hover events reach children
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: (mouse) => { mouse.accepted = true }
        }
    }

    // SubMenu component with internal Opener
    Item {
        id: subMenu
        x: root.outerPadding
        y: root.outerPadding
        width: root.menuWidth
        implicitHeight: Math.min(menuContent.implicitHeight, root.maxMenuHeight)
        height: implicitHeight
        clip: true

        Flickable {
            id: menuFlickable
            anchors.fill: parent
            contentWidth: width
            contentHeight: menuContent.implicitHeight
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            clip: true

            Column {
                id: menuContent
                width: menuFlickable.width
                spacing: 0
                topPadding: Theme.spacingXSmall
                bottomPadding: Theme.spacingXSmall

                QsMenuOpener {
                    id: menuOpener
                    menu: root.menuHandle
                }

                Repeater {
                    model: menuOpener.children

                    delegate: Rectangle {
                        id: entry
                        required property var modelData
                        readonly property var menuEntry: modelData || null

                        width: subMenu.width
                        implicitHeight: menuEntry && menuEntry.isSeparator ? 9 : 30
                        color: menuEntry && (itemMouseArea.containsMouse || root.activeSubMenuEntry === menuEntry) ? Theme.menuHover : Theme.transparent
                        radius: Theme.radiusMedium

                        property bool countedHover: false

                        function setCountedHover(hovered) {
                            if (countedHover === hovered) {
                                return
                            }

                            countedHover = hovered
                            root.hoveredRowCount += hovered ? 1 : -1
                            if (root.hoveredRowCount < 0) {
                                root.hoveredRowCount = 0
                            }
                        }

                        Component.onDestruction: setCountedHover(false)

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: root.itemPadding
                            anchors.rightMargin: root.itemPadding
                            spacing: Theme.spacingComfortable
                            visible: entry.menuEntry !== null && !entry.menuEntry.isSeparator

                            IconImage {
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                                Layout.alignment: Qt.AlignVCenter
                                source: {
                                    let icon = entry.menuEntry ? (entry.menuEntry.icon || "") : ""
                                    if (!icon) return ""

                                    if (icon.includes("?path=")) {
                                        const chunks = icon.split("?path=");
                                        const namePart = chunks[0];
                                        const pathPart = chunks[1];
                                        const fileName = namePart.substring(namePart.lastIndexOf("/") + 1);
                                        return `file://${pathPart}/${fileName}`;
                                    }
                                    
                                    // Use theme lookup for icon names
                                    if (!icon.includes("/") && !icon.includes(":")) {
                                        return "image://icon/" + icon;
                                    }
                                    
                                    return icon
                                }
                                visible: source !== ""
                            }
                            
                            Text {
                                text: entry.menuEntry ? (entry.menuEntry.text || "") : ""
                                color: entry.menuEntry && entry.menuEntry.enabled ? Theme.selFg : Theme.menuDisabledFg
                                font.pointSize: Theme.menuPointSize
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter
                                elide: Text.ElideRight
                            }
                            
                            Text {
                                text: ""
                                font.family: Theme.fontIcon
                                font.pointSize: Theme.menuIconPointSize
                                color: Theme.selFg
                                Layout.alignment: Qt.AlignVCenter
                                visible: entry.menuEntry !== null && entry.menuEntry.hasChildren
                                Component.onCompleted: if (contentWidth === 0) text = ">"
                            }
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width - root.itemPadding * 2
                            height: 1
                            color: Theme.menuHover
                            visible: entry.menuEntry !== null && entry.menuEntry.isSeparator
                        }

                        MouseArea {
                            id: itemMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: entry.menuEntry !== null && entry.menuEntry.enabled && !entry.menuEntry.isSeparator

                            onContainsMouseChanged: entry.setCountedHover(containsMouse)

                            onEntered: {
                                if (entry.menuEntry && entry.menuEntry.hasChildren) {
                                    root.showSubMenu(entry.menuEntry, entry);
                                } else {
                                    root.closeSubMenu();
                                }
                            }
                            
                            onClicked: {
                                if (!entry.menuEntry)
                                    return;
                                if (entry.menuEntry.hasChildren) {
                                    root.showSubMenu(entry.menuEntry, entry);
                                } else {
                                    entry.menuEntry.triggered();
                                    root.forceClose();
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: scrollIndicator
            z: 2
            width: 3
            height: Math.max(0, Math.min(parent.height - 8, Math.max(24, menuFlickable.visibleArea.heightRatio * parent.height)))
            x: parent.width - width - 3
            y: Math.max(0, Math.min(parent.height - height - 4, Math.max(4, menuFlickable.visibleArea.yPosition * parent.height)))
            radius: Theme.radiusSmall
            color: Theme.scrollIndicator
            visible: menuFlickable.interactive
        }
    }
}
