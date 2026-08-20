import QtQuick
import Quickshell
import Quickshell.Wayland
import "."

PanelWindow { // qmllint disable uncreatable-type
    id: root
    objectName: "shell-popup-window"

    property var anchorWindow
    property var monitor: anchorWindow ? anchorWindow.screen : null
    property var anchorItem
    property real anchorX: 0
    property real anchorY: 0
    property real anchorWidth: 0
    property real anchorHeight: 0
    property real pointerX: -1
    property real pointerY: -1
    property int edgeMargin: 0
    property int topMargin: 0
    property int anchorGap: 0
    property int barOverlap: 1
    property bool dismissOnHoverLeave: true
    property int hoverOpenGraceMs: 900
    property int hoverDismissDelayMs: 500
    property bool isAnchorHovered: false
    property var currentComponent: null
    property var pendingProperties: ({})
    readonly property var loadedItem: contentLoader.item
    readonly property bool anchorContainsPointer: anchorItem !== null && anchorItem !== undefined && pointerX >= 0 && pointerY >= 0 && pointerX >= anchorX && pointerX <= anchorX + anchorWidth && pointerY >= anchorY && pointerY <= anchorY + anchorHeight
    readonly property bool containsPopupMouse: backgroundHover.hovered || containerHover.hovered || isAnchorHovered || anchorContainsPointer

    screen: monitor

    // Allow children to be added directly to the container
    default property alias content: container.data

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-popup"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.exclusiveZone: -1

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: Theme.transparent

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

    function updatePointerPosition(x, y) {
        pointerX = x;
        pointerY = y;
        updateHoverDismiss();
    }

    function open(component, item, properties) {
        currentComponent = component;
        anchorItem = item || null;
        pendingProperties = properties || ({});
        contentLoader.setSource(component, pendingProperties);
        visible = true;
    }

    function close() {
        visible = false;
    }

    function toggle(component, item, properties) {
        if (visible && currentComponent === component && anchorItem === item) {
            close();
            return;
        }
        open(component, item, properties);
    }

    function preferredX() {
        if (!anchorItem)
            return edgeMargin;

        return anchorX + anchorWidth / 2 - background.width / 2;
    }

    function preferredY() {
        if (!anchorItem)
            return topMargin;

        const barBottom = anchorWindow && anchorWindow.height > 0 ? anchorWindow.height : anchorY + anchorHeight;
        return Math.max(topMargin, barBottom - barOverlap + anchorGap);
    }

    function clampedX() {
        const maxX = Math.max(edgeMargin, root.width - background.width - edgeMargin);
        return Math.min(maxX, Math.max(edgeMargin, preferredX()));
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

        if (hoverGraceTimer.running || containsPopupMouse) {
            hoverDismissTimer.stop();
        } else {
            if (!hoverDismissTimer.running) {
                hoverDismissTimer.start();
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            updateAnchorMetrics();
            armHoverDismiss();
        } else {
            hoverGraceTimer.stop();
            hoverDismissTimer.stop();
            pointerX = -1;
            pointerY = -1;
            currentComponent = null;
            anchorItem = null;
            pendingProperties = ({});
            contentLoader.source = "";
        }
    }

    onAnchorItemChanged: {
        updateAnchorMetrics();
        armHoverDismiss();
    }

    MouseArea {
        id: overlayMouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.visible = false
        onContainsMouseChanged: {
            if (!containsMouse) {
                root.pointerX = -1;
                root.pointerY = -1;
            }
            root.updateHoverDismiss();
        }
        onPositionChanged: mouse => root.updatePointerPosition(mouse.x, mouse.y)
    }

    Connections {
        target: root.anchorItem ? root.anchorItem : null

        function onXChanged() {
            root.updateAnchorMetrics();
        }
        function onYChanged() {
            root.updateAnchorMetrics();
        }
        function onWidthChanged() {
            root.updateAnchorMetrics();
        }
        function onHeightChanged() {
            root.updateAnchorMetrics();
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
            if (root.visible && root.dismissOnHoverLeave && !root.containsPopupMouse) {
                root.visible = false;
            }
        }
    }

    Timer {
        interval: 250
        repeat: true
        running: root.visible && root.dismissOnHoverLeave && !hoverGraceTimer.running
        onTriggered: root.updateHoverDismiss()
    }

    Rectangle {
        id: background
        z: 10
        x: root.clampedX()
        y: root.preferredY()
        width: implicitWidth
        height: implicitHeight
        implicitWidth: container.width + (container.padding * 2)
        implicitHeight: container.height + (container.padding * 2)

        color: Theme.bg
        border.color: Theme.border
        border.width: 1
        radius: Theme.radiusNone

        HoverHandler {
            id: backgroundHover
            onHoveredChanged: root.updateHoverDismiss()
        }

        MouseArea {
            anchors.fill: parent
            onClicked: mouse => {
                mouse.accepted = true;
            }
        }

        Item {
            id: container
            x: padding
            y: padding
            property int padding: Theme.popupPadding

            HoverHandler {
                id: containerHover
                onHoveredChanged: root.updateHoverDismiss()
            }

            // Drive size from first child's implicit size
            width: children.length > 0 ? children[0].implicitWidth : 0
            height: children.length > 0 ? children[0].implicitHeight : 0

            Loader {
                id: contentLoader

                // qmllint disable missing-property
                onStatusChanged: {
                    if (status === Loader.Ready && item) {
                        if (item.requestClose !== undefined)
                            item.requestClose.connect(root.close);
                        if (item.itemTriggered !== undefined)
                            item.itemTriggered.connect(root.close);
                    } else if (status === Loader.Error) {
                        console.warn("ShellPopup: failed to load " + root.currentComponent);
                        root.close();
                    }
                }
                // qmllint enable missing-property
            }
        }
    }

    OpacityAnimator {
        target: root.contentItem
        from: 0
        to: 1
        duration: 200
        running: root.visible
    }
}
