import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell.Widgets
import "../services"

Rectangle {
    id: root
    
    // Explicit properties
    property string summary: ""
    property string body: ""
    property string appIcon: ""
    property string time: ""
    property string trackingId: ""
    property bool showTime: true
    property var notification: null
    
    // Expansion properties
    property bool expandable: false
    property bool expanded: false
    
    // Timeout animation properties
    property bool showTimeoutCircle: false
    property int timeoutDuration: 10000
    property real fractionRemaining: 1.0
    readonly property bool canExpand: root.expandable && (summaryText.truncated || bodyText.truncated || root.expanded)
    readonly property bool canActivate: root.trackingId !== ""

    function iconSource() {
        if (!appIcon) return "";
        if (appIcon.startsWith("image://") || appIcon.startsWith("file://")) return appIcon;
        if (appIcon.startsWith("/")) return "file://" + appIcon;
        return "image://icon/" + appIcon;
    }
    
    NumberAnimation on fractionRemaining {
        id: timerAnimation
        running: root.showTimeoutCircle
        from: 1.0
        to: 0.0
        duration: root.timeoutDuration
    }
    
    implicitWidth: 350
    implicitHeight: cardLayout.implicitHeight + 20
    height: implicitHeight
    
    color: Theme.bg
    border.color: (cardClickArea.containsMouse && (root.canActivate || root.canExpand)) ? Theme.selBg : Theme.border
    border.width: 1
    radius: Theme.radiusNone

    // Handle clicks and hovers for activating the notification
    MouseArea {
        id: cardClickArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: (root.canActivate || root.canExpand) ? Qt.PointingHandCursor : Qt.ArrowCursor
        
        onClicked: (mouse) => {
            if (root.canActivate && Notifications.activateByTrackingId(root.trackingId)) {
                mouse.accepted = true;
                return;
            }

            if (root.canExpand) {
                root.expanded = !root.expanded;
                mouse.accepted = true;
            }
        }
    }

    RowLayout {
        id: cardLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.controlPadding
        spacing: Theme.spacingLarge

        IconImage {
            id: appIconImage
            // Remember which URL failed so the fallback survives Image.Error
            // without destroying the declarative source binding; a new icon
            // URL from an app-icon update is retried normally.
            property string failedSource: ""
            source: {
                const resolved = root.iconSource();
                return resolved !== "" && resolved === failedSource
                    ? "image://icon/dialog-information"
                    : resolved;
            }
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            Layout.alignment: Qt.AlignTop
            visible: root.iconSource() !== ""
            onStatusChanged: if (status === Image.Error) failedSource = root.iconSource()
        }
        
        // Content
        ColumnLayout {
            spacing: Theme.spacingXSmall
            Layout.fillWidth: true
            
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingMedium
                
                Text {
                    id: summaryText
                    text: root.summary
                    color: Theme.selFg
                    font.pixelSize: Theme.fontSizeTitle
                    font.family: Theme.fontMono
                    font.bold: true
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    maximumLineCount: root.expandable ? (root.expanded ? 100 : 1) : 3
                    elide: root.expanded ? Text.ElideNone : Text.ElideRight
                    Layout.fillWidth: true
                }
                
                Text {
                    text: root.time
                    color: Theme.fg
                    font.pixelSize: Theme.fontSizeLabel
                    font.family: Theme.fontMono
                    opacity: Theme.opacityMuted
                    Layout.alignment: Qt.AlignTop | Qt.AlignRight
                    visible: root.showTime
                }
            }
            
            Text {
                id: bodyText
                text: root.body
                color: Theme.fg
                font.pixelSize: Theme.fontSizeLabel
                font.family: Theme.fontMono
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: root.expandable ? (root.expanded ? 100 : 1) : 3
                elide: root.expanded ? Text.ElideNone : Text.ElideRight
                Layout.fillWidth: true
                visible: root.body !== ""
            }
            
            // Expand / Collapse indicator
            Item {
                id: expandToggle
                Layout.fillWidth: true
                implicitHeight: expandLabel.implicitHeight
                visible: root.canExpand
                
                Text {
                    id: expandLabel
                    text: root.expanded ? "Collapse ▲" : "Expand ▼"
                    color: Theme.selBg
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontMono
                    font.bold: true
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (mouse) => {
                        root.expanded = !root.expanded;
                        mouse.accepted = true;
                    }
                }
            }
        }
        
        // Close Button
        MouseArea {
            id: closeButton
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            Layout.alignment: Qt.AlignTop
            cursorShape: Qt.PointingHandCursor
            
            // Track Circle (Faint background)
            Rectangle {
                visible: root.showTimeoutCircle
                anchors.centerIn: parent
                width: 24
                height: 24
                radius: Theme.radiusAction
                color: Theme.transparent
                border.color: Theme.border
                border.width: 1
                opacity: Theme.opacitySoft
            }

            // Active Path (Unwinding arc)
            Shape {
                id: timerCircle
                visible: root.showTimeoutCircle
                anchors.fill: parent
                layer.enabled: true
                layer.samples: 4
                
                ShapePath {
                    fillColor: Theme.transparent
                    strokeColor: Theme.selBg
                    strokeWidth: 2
                    capStyle: ShapePath.RoundCap
                    
                    PathAngleArc {
                        centerX: 15
                        centerY: 15
                        radiusX: 12
                        radiusY: 12
                        startAngle: -90
                        sweepAngle: 360 * root.fractionRemaining
                    }
                }
            }
            
            IconImage {
                anchors.centerIn: parent
                width: 20
                height: 20
                source: "image://icon/window-close"
            }
            
            onClicked: (mouse) => {
                mouse.accepted = true;
                if (root.trackingId !== "") {
                    Notifications.dismissByTrackingId(root.trackingId)
                } else {
                    Notifications.dismiss(root.notification)
                }
            }
        }
    }
}
