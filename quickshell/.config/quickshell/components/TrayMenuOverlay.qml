import QtQuick
import Quickshell
import Quickshell.Wayland
import "." as Components

PanelWindow { // qmllint disable uncreatable-type
    id: root
    objectName: "tray-menu-overlay"

    property var monitor: null
    property var anchorWindow: null
    property var menuHandle: null
    property var anchorItem: null
    property real anchorX: 0
    property real anchorY: 0
    property real anchorWidth: 0
    property real anchorHeight: 0
    property int edgeMargin: Theme.controlPadding
    property int topMargin: 0
    property int anchorGap: Theme.spacingSmall
    property int barOverlap: 0
    property bool dismissOnHoverLeave: true
    property int hoverOpenGraceMs: 900
    property int hoverDismissDelayMs: 650
    readonly property bool containsMenuMouse: trayMenu.containsMenuMouse

    screen: monitor
    visible: false
    color: Theme.transparent

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-tray-menu"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.exclusiveZone: -1

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    function open(handle, item, targetMonitor) {
        menuHandle = handle;
        anchorItem = item;
        monitor = targetMonitor;
        updateAnchorMetrics();
        visible = true;
    }

    function close() {
        visible = false;
    }

    function toggle(handle, item, targetMonitor) {
        if (visible && menuHandle === handle) {
            close();
        } else {
            open(handle, item, targetMonitor);
        }
    }

    function updateAnchorMetrics() {
        if (!anchorItem) {
            anchorX = edgeMargin;
            anchorY = 0;
            anchorWidth = 0;
            anchorHeight = 0;
            return;
        }

        const pos = anchorItem.mapToItem(null, 0, 0);
        anchorX = pos.x;
        anchorY = pos.y;
        anchorWidth = anchorItem.width;
        anchorHeight = anchorItem.height;
    }

    function menuX() {
        if (!anchorItem)
            return edgeMargin;

        const preferred = anchorX + anchorWidth / 2 - trayMenu.implicitWidth / 2;
        const maxX = Math.max(edgeMargin, root.width - trayMenu.implicitWidth - edgeMargin);
        return Math.min(maxX, Math.max(edgeMargin, preferred));
    }

    function menuY() {
        if (!anchorItem)
            return topMargin;

        const barBottom = anchorWindow && anchorWindow.height > 0 ? anchorWindow.height : anchorY + anchorHeight;
        return Math.max(topMargin, barBottom - barOverlap + anchorGap);
    }

    function armHoverDismiss() {
        if (!dismissOnHoverLeave || !visible) {
            hoverGraceTimer.stop();
            hoverDismissTimer.stop();
            return;
        }

        hoverGraceTimer.restart();
        hoverDismissTimer.stop();
    }

    function updateHoverDismiss() {
        if (!dismissOnHoverLeave || !visible) {
            hoverGraceTimer.stop();
            hoverDismissTimer.stop();
            return;
        }

        if (hoverGraceTimer.running || containsMenuMouse) {
            hoverDismissTimer.stop();
        } else {
            if (!hoverDismissTimer.running) {
                hoverDismissTimer.start();
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            armHoverDismiss();
        } else {
            hoverGraceTimer.stop();
            hoverDismissTimer.stop();
            menuHandle = null;
            anchorItem = null;
        }
    }

    Timer {
        id: hoverGraceTimer
        interval: root.hoverOpenGraceMs
        repeat: false
        onTriggered: root.updateHoverDismiss()
    }

    Timer {
        id: hoverDismissTimer
        interval: root.hoverDismissDelayMs
        repeat: false
        onTriggered: {
            if (root.visible && root.dismissOnHoverLeave && !root.containsMenuMouse) {
                root.close();
            }
        }
    }

    MouseArea {
        id: overlayMouseArea
        anchors.fill: parent
        hoverEnabled: true
        focus: true
        onClicked: root.close()
        onContainsMouseChanged: root.updateHoverDismiss()
        onPositionChanged: root.updateHoverDismiss()
        Keys.onEscapePressed: event => { // qmllint disable signal-handler-parameters
            event.accepted = true;
            root.close();
        } // qmllint enable signal-handler-parameters
    }

    Components.TrayMenu {
        id: trayMenu
        z: 10
        x: root.menuX()
        y: root.menuY()
        menuHandle: root.menuHandle
        monitor: root.monitor
        isSubMenu: true
        usePopupSubmenus: false
        onItemTriggered: root.close()
        onRequestClose: root.close()
        onContainsMenuMouseChanged: root.updateHoverDismiss()
    }
}
