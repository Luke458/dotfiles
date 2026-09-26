pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../services"

Item {
    id: root
    
    implicitWidth: 350
    implicitHeight: mainLayout.implicitHeight + Theme.sectionPadding * 2
    
    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: Theme.sectionPadding
        spacing: Theme.spacingLarge

        // Month navigation header
        RowLayout {
            Layout.fillWidth: true
            
            StyledButton {
                text: "<"
                fixedWidth: 30
                Accessible.name: "Previous month"
                onClicked: Calendar.changeMonth(-1)
            }

            StyledButton {
                Layout.fillWidth: true
                text: Calendar.monthYearString.toUpperCase()
                font.bold: true
                Accessible.name: text + ", return to current month"
                onClicked: Calendar.resetToCurrentMonth()
            }

            StyledButton {
                text: ">"
                fixedWidth: 30
                Accessible.name: "Next month"
                onClicked: Calendar.changeMonth(1)
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
            columnSpacing: Theme.spacingSmall
            rowSpacing: Theme.spacingSmall

            property int selectedIndex: -1

            // A raw index means nothing after the month changes; clear the
            // selection so it cannot highlight a different month's day.
            Connections {
                target: Calendar
                function onCalendarDaysChanged() {
                    grid.selectedIndex = -1;
                }
            }

            Repeater {
                model: Calendar.calendarDays
                delegate: StyledButton {
                    id: dayDelegate
                    required property int index
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    Layout.preferredWidth: 1
                    horizontalPadding: 0
                    text: String(modelData.day)
                    enabled: modelData.isCurrentMonth
                    selected: grid.selectedIndex === index || modelData.isToday
                    font.bold: modelData.isToday
                    Accessible.name: Calendar.monthYearString + " " + modelData.day + (modelData.isToday ? ", today" : "")
                    onClicked: grid.selectedIndex = index
                }
            }
        }
    }
}
