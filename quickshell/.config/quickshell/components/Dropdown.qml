pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "."

// Compact select control. `model` may be a JS array of strings or objects;
// when objects are used, set `textRole` to the label property. The list opens
// inline (no Qt Popup) so it renders inside Wayland layer surfaces.
FocusScope {
    id: root

    property var model: []
    property int currentIndex: -1
    property string textRole: ""
    property bool expanded: false

    readonly property string currentText: {
        const values = model || [];
        if (currentIndex < 0 || currentIndex >= values.length) return "";
        return textOf(values[currentIndex]);
    }

    signal activated(int index)

    implicitWidth: Theme.space(160)
    implicitHeight: Theme.space(30)
    activeFocusOnTab: true

    function textOf(item) {
        if (item === undefined || item === null) return "";
        if (typeof item === "string" || typeof item === "number") return String(item);
        if (textRole !== "" && item[textRole] !== undefined) return String(item[textRole]);
        return String(item.text !== undefined ? item.text : (item.name !== undefined ? item.name : (item.label !== undefined ? item.label : "")));
    }

    function close() { expanded = false; }

    StyledButton {
        id: button
        anchors.fill: parent
        text: root.currentText
        iconText: root.expanded ? "\uf077" : "\uf078"
        bordered: true
        onClicked: {
            root.expanded = !root.expanded;
            if (root.expanded) root.forceActiveFocus();
        }
    }

    Rectangle {
        id: list
        visible: root.expanded
        z: 300
        y: root.height + Theme.spacingXSmall
        width: root.width
        height: Math.min(Math.max(root.model.length, 1), 8) * Theme.space(28) + Theme.spacingXSmall * 2
        color: Theme.bgSolid
        border.color: Theme.border
        border.width: 1
        radius: Theme.radiusMedium

        ListView {
            anchors.fill: parent
            anchors.margins: Theme.spacingXSmall
            clip: true
            model: root.model

            delegate: Rectangle {
                id: row
                required property int index
                required property var modelData

                width: ListView.view.width
                height: Theme.space(28)
                color: rowHover.hovered || row.index === root.currentIndex ? Theme.hover : Theme.transparent

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingCompact
                    anchors.rightMargin: Theme.spacingCompact
                    verticalAlignment: Text.AlignVCenter
                    text: root.textOf(row.modelData)
                    color: Theme.fg
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.panelBodySize
                    elide: Text.ElideRight
                }

                HoverHandler { id: rowHover }
                TapHandler {
                    onTapped: {
                        root.currentIndex = row.index;
                        root.activated(row.index);
                        root.close();
                    }
                }
            }
        }
    }

    onActiveFocusChanged: if (!activeFocus && !list.activeFocus) expanded = false
    Keys.onEscapePressed: event => { expanded = false; event.accepted = true; }
    Keys.onReturnPressed: event => { expanded = !expanded; event.accepted = true; }
}
