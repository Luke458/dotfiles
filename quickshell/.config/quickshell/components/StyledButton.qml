import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// One compact, keyboard-accessible button for flyouts and panels.
Button {
    id: root

    property string iconText: ""
    property bool bordered: false
    property bool selected: false
    property int fixedWidth: 0
    property color tint: "transparent"
    readonly property bool _tinted: tint.a > 0

    implicitWidth: fixedWidth > 0 ? fixedWidth : Math.ceil(Math.max(labelMetrics.advanceWidth, labelMetrics.boundingRect.width)) + (iconText ? Math.ceil(iconMetrics.advanceWidth) : 0) + (iconText && text ? Theme.spacingSmall : 0) + leftPadding + rightPadding
    implicitHeight: 30
    horizontalPadding: Theme.controlPadding + 1
    verticalPadding: 4
    font.family: Theme.fontMono
    font.pixelSize: Theme.panelBodySize
    font.bold: selected
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true
    opacity: enabled ? 1 : Theme.opacityDisabled
    Accessible.name: text || iconText

    TextMetrics {
        id: labelMetrics
        text: root.text
        font: root.font
    }

    background: Rectangle {
        radius: Theme.radiusMedium
        color: root.down || root.selected || root.visualFocus ? Theme.selBg
            : root.hovered ? Theme.hover
            : root._tinted ? Theme.withAlpha(root.tint, 0.12)
            : root.bordered ? Theme.surfaceSubtle : Theme.transparent
        border.color: root.visualFocus || root.selected ? Theme.selBg
            : root._tinted ? root.tint : Theme.controlBorder(false, root.hovered, false)
        border.width: root._tinted || root.bordered || root.selected || root.hovered || root.visualFocus ? 1 : 0
    }

    contentItem: RowLayout {
        spacing: root.iconText && root.text ? Theme.spacingSmall : 0
        Text {
            visible: root.iconText !== ""
            text: root.iconText
            font.family: Theme.fontIcon
            font.pixelSize: Theme.panelBodySize
            color: Theme.controlText(root.visualFocus || root.down, root.hovered, root.selected, true)
        }
        Text {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            text: root.text
            visible: root.text !== ""
            textFormat: Text.PlainText
            elide: Text.ElideRight
            font: root.font
            color: Theme.controlText(root.visualFocus || root.down, root.hovered, root.selected, true)
            horizontalAlignment: Text.AlignHCenter
        }
        TextMetrics {
            id: iconMetrics
            text: root.iconText
            font.family: Theme.fontIcon
            font.pixelSize: Theme.panelBodySize
        }
    }
}
