pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets
import "../services"

Item {
    id: root

    property bool titleExpanded: false

    implicitWidth: 350
    implicitHeight: mainLayout.implicitHeight + 40
    
    ColumnLayout {
        id: mainLayout
        anchors.centerIn: parent
        width: parent.width - 40
        spacing: Theme.spacingXLarge
        visible: Media.hasMedia

        // Album Art and Metadata
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingXLarge
            
            Rectangle {
                Layout.preferredWidth: 80
                Layout.preferredHeight: 80
                radius: Theme.radiusMedium
                color: Theme.border
                clip: true
                
                Image {
                    anchors.fill: parent
                    source: Media.albumArtUrl || "image://icon/media-optical"
                    fillMode: Image.PreserveAspectCrop
                }
            }
            
            ColumnLayout {
                spacing: Theme.spacingXSmall
                Layout.fillWidth: true

                // Title row — click to expand/collapse
                Item {
                    Layout.fillWidth: true
                    implicitHeight: titleCol.implicitHeight + 10

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusMedium
                        color: Theme.transparent
                        border.width: 1
                        border.color: (titleHover.containsMouse || root.titleExpanded) ? Theme.selBg : Theme.transparent

                        Behavior on border.color {
                            ColorAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }
                    }

                    ColumnLayout {
                        id: titleCol
                        anchors {
                            left: parent.left; right: parent.right
                            top: parent.top
                            leftMargin: 5; rightMargin: 5; topMargin: 5
                        }
                        spacing: Theme.spacingTiny

                        Text {
                            id: titleText
                            text: Media.trackTitle
                            color: Theme.selFg
                            font.pixelSize: Theme.fontSizeHeadingLarge
                            font.family: Theme.fontMono
                            font.bold: true
                            wrapMode: Text.Wrap
                            maximumLineCount: root.titleExpanded ? 100 : 1
                            elide: root.titleExpanded ? Text.ElideNone : Text.ElideRight
                            Layout.fillWidth: true
                        }

                        // Expand / Collapse indicator
                        Text {
                            text: root.titleExpanded ? "Collapse ▲" : "Expand ▼"
                            color: Theme.selBg
                            font.pixelSize: Theme.fontSizeSmall
                            font.family: Theme.fontMono
                            font.bold: true
                            visible: titleText.truncated || root.titleExpanded
                        }
                    }

                    MouseArea {
                        id: titleHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: (titleText.truncated || root.titleExpanded) ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (titleText.truncated || root.titleExpanded)
                                root.titleExpanded = !root.titleExpanded
                        }
                    }
                }

                Text {
                    text: Media.trackArtist
                    color: Theme.fg
                    font.pixelSize: Theme.fontSizeBar
                    font.family: Theme.fontMono
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: Media.trackAlbum || ""
                    color: Theme.fg
                    font.pixelSize: Theme.fontSizeBody
                    font.family: Theme.fontMono
                    opacity: Theme.opacitySecondaryLow
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    visible: text !== ""
                }
            }
        }

        // Progress Bar
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingSmall
            
            Slider {
                id: progressSlider
                Layout.fillWidth: true
                from: 0
                to: 1
                value: (Media.trackLength > 0) ? (Media.currentPosition * 1e6 / Media.trackLength) : 0
                
                background: Rectangle {
                    x: progressSlider.leftPadding
                    y: progressSlider.topPadding + progressSlider.availableHeight / 2 - height / 2
                    implicitWidth: 200
                    implicitHeight: 4
                    width: progressSlider.availableWidth
                    height: implicitHeight
                    radius: Theme.radiusSmall
                    color: Theme.border
                    opacity: Theme.opacitySoft

                    Rectangle {
                        width: progressSlider.visualPosition * parent.width
                        height: parent.height
                        color: Theme.selBg
                        radius: Theme.radiusSmall
                    }
                }

                handle: Rectangle {
                    x: progressSlider.leftPadding + progressSlider.visualPosition * (progressSlider.availableWidth - width)
                    y: progressSlider.topPadding + progressSlider.availableHeight / 2 - height / 2
                    implicitWidth: 10
                    implicitHeight: 10
                    radius: Theme.radiusComfortable
                    color: Theme.selFg
                    visible: progressSlider.hovered || progressSlider.pressed
                }
                
                onMoved: Media.seek(value)
            }
            
            RowLayout {
                Layout.fillWidth: true
                
                Text {
                    text: root.formatTime(Media.currentPosition)
                    color: Theme.fg
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontMono
                }
                
                Item { Layout.fillWidth: true }
                
                Text {
                    text: root.formatTime(Media.trackLength / 1e6)
                    color: Theme.fg
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontMono
                }
            }
        }

        // Controls
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Theme.spacingHero
            
            Button {
                id: prevBtn
                flat: true
                enabled: Media.canGoPrevious
                onClicked: Media.previous()
                
                background: Rectangle {
                    implicitWidth: 40
                    implicitHeight: 40
                    radius: Theme.radiusMedium
                    color: prevBtn.hovered ? Theme.hover : Theme.transparent
                }
                
                contentItem: IconImage {
                    source: "image://icon/media-skip-backward"
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                }
            }
            
            Button {
                id: playBtn
                flat: true
                onClicked: Media.togglePlayPause()
                
                background: Rectangle {
                    implicitWidth: 50
                    implicitHeight: 50
                    radius: Theme.radiusMedium
                    color: playBtn.hovered ? Theme.hover : Theme.transparent
                }
                
                contentItem: IconImage {
                    source: Media.playbackState === 1 ? "image://icon/media-playback-pause" : "image://icon/media-playback-start"
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                }
            }
            
            Button {
                id: nextBtn
                flat: true
                enabled: Media.canGoNext
                onClicked: Media.next()
                
                background: Rectangle {
                    implicitWidth: 40
                    implicitHeight: 40
                    radius: Theme.radiusMedium
                    color: nextBtn.hovered ? Theme.hover : Theme.transparent
                }
                
                contentItem: IconImage {
                    source: "image://icon/media-skip-forward"
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: "NO MEDIA PLAYING"
        color: Theme.fg
        font.pixelSize: Theme.fontSizeBar
        font.family: Theme.fontMono
        visible: !Media.hasMedia
    }

    function formatTime(seconds) {
        if (isNaN(seconds) || seconds < 0) return "0:00";
        const mins = Math.floor(seconds / 60);
        const secs = Math.floor(seconds % 60);
        return mins + ":" + (secs < 10 ? "0" : "") + secs;
    }
}
