import QtQuick
import QtQuick.Layouts
import "."
import "../services"

Item {
    id: root

    implicitWidth: 400
    implicitHeight: mainLayout.implicitHeight + 40

    // Chart color is exposed for the Canvas renderer.
    property color chartColor: Theme.selBg

    function fmtUSD(n) {
        if (!n) return "$—"
        return "$" + Math.round(n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",")
    }
    function fmtAUD(n) {
        if (!n) return "A$—"
        return "A$" + Math.round(n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",")
    }

    // Repaint chart whenever the service's cached prices update
    Connections {
        target: Btc
        function onPricesChanged() { chart.requestPaint() }
    }

    ColumnLayout {
        id: mainLayout
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
        spacing: Theme.spacingPanel

        // ── Header ───────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "₿  Bitcoin"
                color: Theme.selFg
                font.pixelSize: Theme.fontSizeDisplaySmall
                font.family: Theme.fontMono
                font.bold: true
            }

            Item { Layout.fillWidth: true }

            // 24h change badge
            Rectangle {
                visible: !Btc.loading && !Btc.hasError
                radius: Theme.radiusMedium
                color: Btc.changePct >= 0 ? Theme.positiveSurface : Theme.negativeSurface
                implicitWidth:  badgeText.implicitWidth  + 14
                implicitHeight: badgeText.implicitHeight + 6

                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: (Btc.changePct >= 0 ? "+" : "") + Btc.changePct.toFixed(2) + "%  24h"
                    color: Btc.changePct >= 0 ? Theme.positive : Theme.negative
                    font.pixelSize: Theme.fontSizeBody
                    font.family: Theme.fontMono
                    font.bold: true
                }
            }

            // Loading spinner dot (only on first fetch — not on background refresh)
            Rectangle {
                visible: Btc.loading
                implicitWidth: 8; implicitHeight: 8; radius: Theme.radiusMedium
                color: Theme.selBg
                SequentialAnimation on opacity {
                    running: Btc.loading
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.2; duration: 600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                }
            }
        }

        // ── Prices + 24h High/Low ──────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            visible: !Btc.loading && !Btc.hasError
            spacing: 0

            // Left: current price
            ColumnLayout {
                spacing: Theme.spacingTiny

                Text {
                    text: root.fmtUSD(Btc.currentUsd)
                    color: Theme.selFg
                    font.pixelSize: Theme.fontSizeValueLarge
                    font.family: Theme.fontMono
                    font.bold: true
                }

                Text {
                    text: root.fmtAUD(Btc.currentAud)
                    color: Theme.fg
                    font.pixelSize: Theme.fontSizeTitle
                    font.family: Theme.fontMono
                    opacity: Theme.opacitySecondary
                }
            }

            Item { Layout.fillWidth: true }

            // Right: 24h high / low
            ColumnLayout {
                spacing: Theme.spacingComfortable
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter

                ColumnLayout {
                    spacing: Theme.spacingMicro
                    Layout.alignment: Qt.AlignRight

                    Text {
                        text: "24H HIGH"
                        color: Theme.fg; font.pixelSize: Theme.fontSizeCaption; font.family: Theme.fontMono; opacity: Theme.opacityMuted
                        Layout.alignment: Qt.AlignRight
                    }
                    Text {
                        text: root.fmtUSD(Btc.high24h)
                        color: Theme.positive
                        font.pixelSize: Theme.fontSizeTitle; font.family: Theme.fontMono; font.bold: true
                        Layout.alignment: Qt.AlignRight
                    }
                }

                ColumnLayout {
                    spacing: Theme.spacingMicro
                    Layout.alignment: Qt.AlignRight

                    Text {
                        text: "24H LOW"
                        color: Theme.fg; font.pixelSize: Theme.fontSizeCaption; font.family: Theme.fontMono; opacity: Theme.opacityMuted
                        Layout.alignment: Qt.AlignRight
                    }
                    Text {
                        text: root.fmtUSD(Btc.low24h)
                        color: Theme.negative
                        font.pixelSize: Theme.fontSizeTitle; font.family: Theme.fontMono; font.bold: true
                        Layout.alignment: Qt.AlignRight
                    }
                }
            }
        }

        Text {
            visible: Btc.hasError && !Btc.loading && !Btc.hasCachedData
            text: "Failed to fetch data"
            color: Theme.negative
            font.pixelSize: Theme.fontSizeBar
            font.family: Theme.fontMono
            Layout.alignment: Qt.AlignHCenter
        }

        // ── Chart ─────────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 140
            color: Theme.withAlpha(root.chartColor, 0.04)
            radius: Theme.radiusPanel
            border.color: Theme.border
            border.width: 1
            visible: Btc.prices.length > 1

            Canvas {
                id: chart
                anchors { fill: parent; margins: 8 }

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)

                    var prices = Btc.prices
                    if (prices.length < 2) return

                    var minP  = Math.min.apply(null, prices)
                    var maxP  = Math.max.apply(null, prices)
                    var range = (maxP - minP) || 1
                    var n = prices.length
                    var w = width
                    var h = height

                    var pts = []
                    for (var i = 0; i < n; i++) {
                        pts.push({
                            x: (i / (n - 1)) * w,
                            y: (1 - (prices[i] - minP) / range) * h
                        })
                    }

                    var lineColor = Theme.cssRgb(root.chartColor)

                    // Gradient fill
                    var grad = ctx.createLinearGradient(0, 0, 0, h)
                    grad.addColorStop(0, Theme.cssRgba(root.chartColor, Theme.chartFillOpacity))
                    grad.addColorStop(1, Theme.cssRgba(root.chartColor, 0))

                    ctx.beginPath()
                    ctx.moveTo(pts[0].x, pts[0].y)
                    for (var j = 1; j < n; j++) ctx.lineTo(pts[j].x, pts[j].y)
                    ctx.lineTo(pts[n - 1].x, h)
                    ctx.lineTo(pts[0].x, h)
                    ctx.closePath()
                    ctx.fillStyle = grad
                    ctx.fill()

                    // Price line
                    ctx.beginPath()
                    ctx.strokeStyle = lineColor
                    ctx.lineWidth   = 2
                    ctx.lineJoin    = "round"
                    ctx.lineCap     = "round"
                    ctx.moveTo(pts[0].x, pts[0].y)
                    for (var k = 1; k < n; k++) ctx.lineTo(pts[k].x, pts[k].y)
                    ctx.stroke()

                    // Dot at current price
                    var last = pts[n - 1]
                    ctx.beginPath()
                    ctx.arc(last.x, last.y, 4, 0, Math.PI * 2)
                    ctx.fillStyle = lineColor
                    ctx.fill()
                }
            }

            // High/low chart labels
            Text {
                anchors { top: parent.top; right: parent.right; margins: 6 }
                text: root.fmtUSD(Btc.high24h)
                color: Theme.fg; font.pixelSize: Theme.fontSizeCaption; font.family: Theme.fontMono; opacity: Theme.opacityDisabled
            }
            Text {
                anchors { bottom: parent.bottom; right: parent.right; margins: 6 }
                text: root.fmtUSD(Btc.low24h)
                color: Theme.fg; font.pixelSize: Theme.fontSizeCaption; font.family: Theme.fontMono; opacity: Theme.opacityDisabled
            }
        }


        // ── Footer ────────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            visible: Btc.lastUpdated !== ""

            Text {
                text: "via CoinGecko · " + (Btc.stale ? "cached " : "updated ") + Btc.lastUpdated
                color: Theme.fg; font.pixelSize: Theme.fontSizeCaption; font.family: Theme.fontMono; opacity: Theme.opacitySubtle
            }

            Item { Layout.fillWidth: true }

            MouseArea {
                implicitWidth:  refreshIcon.implicitWidth + 8
                implicitHeight: refreshIcon.implicitHeight
                cursorShape: Qt.PointingHandCursor
                onClicked: Btc.refresh()

                Text {
                    id: refreshIcon
                    anchors.centerIn: parent
                    text: "↻"
                    color: Theme.selBg
                    font.pixelSize: Theme.fontSizeTitle; font.family: Theme.fontMono
                    opacity: parent.containsMouse ? 1.0 : 0.5
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }
            }
        }
    }
}
