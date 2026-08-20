pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    // ── Cached state ────────────────────────────────────────────────────────
    property var    prices:      []
    property real   currentUsd:  0
    property real   currentAud:  0
    property real   changePct:   0
    property real   high24h:     0
    property real   low24h:      0
    property bool   loading:     true
    property bool   hasError:    false
    property bool   stale:       false
    property string lastUpdated: ""
    property bool   hasCachedData: prices.length > 0

    // ── Fetch process ────────────────────────────────────────────────────────
    property Process fetchProc: Process {
        command: [Quickshell.shellPath("scripts/btc_chart.sh")]

        stdout: SplitParser {
            onRead: (data) => {
                try {
                    const d = JSON.parse(data)
                    if (d.error) {
                        root.hasError = !root.hasCachedData
                        root.loading  = false
                        root.stale    = root.hasCachedData
                        return
                    }
                    root.prices     = d.prices      || []
                    root.currentUsd = d.current_usd || 0
                    root.currentAud = d.current_aud || 0
                    root.changePct  = d.change_pct  || 0
                    root.high24h    = d.high_24h    || 0
                    root.low24h     = d.low_24h     || 0
                    root.loading    = false
                    root.hasError   = false
                    root.stale      = d.stale || false
                    root.lastUpdated = Qt.formatTime(d.fetched_at ? new Date(d.fetched_at * 1000) : new Date(), "hh:mm")
                } catch(e) {
                    root.hasError = !root.hasCachedData
                    root.loading  = false
                    root.stale    = root.hasCachedData
                }
            }
        }

        onRunningChanged: {
            if (!running && root.loading) {
                root.hasError = !root.hasCachedData
                root.loading  = false
                root.stale    = root.hasCachedData
            }
        }
    }

    // ── Auto-refresh every 5 minutes ─────────────────────────────────────────
    property Timer refreshTimer: Timer {
        interval: 300000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // ── Manual refresh ────────────────────────────────────────────────────────
    function refresh() {
        if (root.fetchProc.running) return
        root.loading = !root.hasCachedData
        root.fetchProc.running = true
    }
}
