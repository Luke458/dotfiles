pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../services"

PanelWindow { // qmllint disable uncreatable-type
    id: root

    property bool activeMonitor: false
    readonly property bool isProgress: Osd.visible && Osd.value >= 0

    visible: activeMonitor && Osd.visible && !remapGuard.remapping

    ScreenMoveRemap {
        id: remapGuard
        window: root
    }

    anchors {
        bottom: true
        left: true
        right: true
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-osd"
    WlrLayershell.exclusiveZone: -1

    color: Theme.transparent

    implicitHeight: card.implicitHeight + Theme.space(48)

    // Purely visual: clicks and scroll events fall through everywhere.
    mask: Region {}

    function glyphFor(key) {
        const map = {
            "volume": "\uf028",
            "volume-low": "\uea27",
            "volume-mute": "\uf6a9",
            "mic": "\uf130",
            "mic-mute": "\uf131",
            "brightness": "\uf185",
            "keyboard": "\uf11c",
            "touchpad": "\uf348",
            "media-play": "\uf04b",
            "media-pause": "\uf04c",
            "media-next": "\uf051",
            "media-previous": "\uf048",
            "copy": "\uf0c5",
            "check": "\uf00c",
            "info": "\uf05a",
            "warning": "\uf071",
            "reboot": "\uf021",
            "power-off": "\uf011",
            "logout": "\uf2f5"
        };
        if (map[key] !== undefined)
            return map[key];
        // Callers may pass a literal glyph instead of a key.
        return key && !/^[a-z0-9-]+$/i.test(key) ? key : "\u{f2eb}";
    }

    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.space(48)

        implicitWidth: contentRow.implicitWidth + Theme.space(40)
        implicitHeight: Math.max(Theme.space(56), contentRow.implicitHeight + Theme.space(24))

        color: Theme.bgSolid
        border.color: Theme.border
        border.width: 1
        radius: Theme.radiusMedium
        opacity: 0.96

        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: Theme.space(16)

            Text {
                text: root.glyphFor(Osd.iconKey)
                font.family: Theme.fontIcon
                font.pixelSize: Theme.fontSizeDisplayLarge
                color: Theme.selFg
                Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
                spacing: Theme.space(8)
                Layout.alignment: Qt.AlignVCenter
                visible: root.isProgress

                Text {
                    text: Osd.progressText.length > 0
                        ? Osd.progressText
                        : Math.round((Osd.value / Osd.maxValue) * 100) + "%"
                    color: Theme.fg
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontSizeLabel
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }

                Rectangle {
                    Layout.preferredWidth: Theme.space(160)
                    Layout.preferredHeight: 6
                    radius: Theme.radiusCompact
                    color: Theme.border
                    clip: true

                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, Osd.value / Osd.maxValue))
                        height: parent.height
                        radius: parent.radius
                        color: Theme.selBg

                        Behavior on width {
                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }

            Text {
                text: Osd.message
                textFormat: Text.PlainText
                visible: !root.isProgress && Osd.message.length > 0
                color: Theme.fg
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeLabel
                elide: Text.ElideRight
                Layout.maximumWidth: Theme.space(280)
            }
        }
    }
}
