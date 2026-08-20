pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../services"

Item {
    id: root
    
    implicitWidth: 350
    implicitHeight: mainLayout.implicitHeight + 40
    
    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: Theme.sectionPadding
        spacing: Theme.spacingLarge

        // Month navigation header
        RowLayout {
            Layout.fillWidth: true
            
            Button {
                id: prevMonthBtn
                text: "<"
                flat: true
                onClicked: Calendar.changeMonth(-1)
                
                background: Rectangle {
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: Theme.radiusMedium
                    color: prevMonthBtn.hovered ? Theme.hover : Theme.transparent
                }
                
                contentItem: Text {
                    text: prevMonthBtn.text
                    color: Theme.selFg
                    font.pixelSize: Theme.fontSizeDisplayLarge
                    font.family: Theme.fontMono
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Text {
                Layout.fillWidth: true
                text: Calendar.monthYearString.toUpperCase()
                color: Theme.selFg
                font.pixelSize: Theme.fontSizeDisplaySmall
                font.family: Theme.fontMono
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: Calendar.resetToCurrentMonth()
                }
            }

            Button {
                id: nextMonthBtn
                text: ">"
                flat: true
                onClicked: Calendar.changeMonth(1)
                
                background: Rectangle {
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: Theme.radiusMedium
                    color: nextMonthBtn.hovered ? Theme.hover : Theme.transparent
                }
                
                contentItem: Text {
                    text: nextMonthBtn.text
                    color: Theme.selFg
                    font.pixelSize: Theme.fontSizeDisplayLarge
                    font.family: Theme.fontMono
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // Day headers
        RowLayout {
            Layout.fillWidth: true
            spacing: 0
            Repeater {
                model: ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]
                delegate: Text {
                    required property string modelData
                    Layout.fillWidth: true
                    text: modelData
                    color: Theme.fg
                    font.pixelSize: Theme.fontSizeLabel
                    font.family: Theme.fontMono
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // Calendar Grid
        GridLayout {
            id: grid
            Layout.fillWidth: true
            columns: 7
            columnSpacing: 5
            rowSpacing: 5

            property int selectedIndex: -1

            Repeater {
                model: Calendar.calendarDays
                delegate: Item {
                    id: dayDelegate
                    required property int index
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: dayText.implicitHeight + 10

                    readonly property bool isSelected: grid.selectedIndex === dayDelegate.index
                    readonly property bool showBorder: dayDelegate.modelData.isCurrentMonth && (isSelected || mouseArea.containsMouse || dayDelegate.modelData.isToday)

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusMedium
                        color: dayDelegate.modelData.isToday ? Theme.selBg : Theme.transparent
                        border.width: 1
                        border.color: dayDelegate.showBorder ? Theme.selBg : Theme.transparent

                        Behavior on border.color {
                            ColorAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }
                    }

                    Text {
                        id: dayText
                        anchors.centerIn: parent
                        text: dayDelegate.modelData.day
                        color: {
                            if (!dayDelegate.modelData.isCurrentMonth) return Qt.alpha(Theme.fg, 0.3);
                            if (dayDelegate.modelData.isToday) return Theme.selFg;
                            return Theme.fg;
                        }
                        font.pixelSize: Theme.fontSizeTitle
                        font.family: Theme.fontMono
                        font.bold: dayDelegate.modelData.isToday
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: grid.selectedIndex = dayDelegate.index
                    }
                }
            }
        }
    }
}
