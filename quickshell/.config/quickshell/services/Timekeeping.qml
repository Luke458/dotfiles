pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property date now: new Date()
    property real timestamp: Date.now()
    property bool use24Hour: false
    property bool showSecondsInBar: false

    property bool stopwatchRunning: false
    property real stopwatchStartedAt: 0
    property real stopwatchAccumulatedMs: 0

    property bool countdownRunning: false
    property real countdownDeadline: 0
    property real countdownRemainingMs: 5 * 60 * 1000
    property real countdownResetMs: 5 * 60 * 1000

    property real uptimeBaseSeconds: 0
    property real uptimeReadAt: 0

    readonly property real stopwatchElapsedMs: stopwatchAccumulatedMs + (stopwatchRunning ? timestamp - stopwatchStartedAt : 0)
    readonly property real uptimeSeconds: uptimeBaseSeconds + (uptimeReadAt > 0 ? (timestamp - uptimeReadAt) / 1000 : 0)
    readonly property string barTime: formatTime(now, showSecondsInBar)
    readonly property string fullTime: formatTime(now, true)
    readonly property string fullDate: Qt.formatDateTime(now, "dddd, MMMM d, yyyy")
    readonly property string stopwatchText: formatDuration(stopwatchElapsedMs, true)
    readonly property string countdownText: formatDuration(countdownRemainingMs, false)
    readonly property string uptimeText: formatUptime(uptimeSeconds)

    function formatTime(value, includeSeconds) {
        const format = use24Hour
            ? (includeSeconds ? "HH:mm:ss" : "HH:mm")
            : (includeSeconds ? "hh:mm:ss AP" : "hh:mm AP");
        return Qt.formatDateTime(value, format);
    }

    function formatDuration(milliseconds, includeTenths) {
        const safeMs = Math.max(0, milliseconds);
        const totalSeconds = Math.floor(safeMs / 1000);
        const hours = Math.floor(totalSeconds / 3600);
        const minutes = Math.floor((totalSeconds % 3600) / 60);
        const seconds = totalSeconds % 60;
        const tenths = Math.floor((safeMs % 1000) / 100);
        const pad = value => value < 10 ? "0" + value : String(value);
        const base = pad(hours) + ":" + pad(minutes) + ":" + pad(seconds);
        return includeTenths ? base + "." + tenths : base;
    }

    function formatUptime(totalSeconds) {
        const seconds = Math.max(0, Math.floor(totalSeconds));
        const days = Math.floor(seconds / 86400);
        const hours = Math.floor((seconds % 86400) / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        const parts = [];
        if (days > 0)
            parts.push(days + " day" + (days === 1 ? "" : "s"));
        if (hours > 0 || days > 0)
            parts.push(hours + " hour" + (hours === 1 ? "" : "s"));
        parts.push(minutes + " minute" + (minutes === 1 ? "" : "s"));
        return parts.join(", ");
    }

    function toggleStopwatch() {
        if (stopwatchRunning) {
            stopwatchAccumulatedMs += Date.now() - stopwatchStartedAt;
            stopwatchRunning = false;
        } else {
            stopwatchStartedAt = Date.now();
            stopwatchRunning = true;
        }
    }

    function resetStopwatch() {
        stopwatchRunning = false;
        stopwatchStartedAt = 0;
        stopwatchAccumulatedMs = 0;
    }

    function adjustCountdown(minutes) {
        if (countdownRunning)
            return;
        countdownRemainingMs = Math.max(0, countdownRemainingMs + minutes * 60 * 1000);
        countdownResetMs = countdownRemainingMs;
    }

    function toggleCountdown() {
        if (countdownRemainingMs <= 0)
            resetCountdown();

        if (countdownRunning) {
            countdownRemainingMs = Math.max(0, countdownDeadline - Date.now());
            countdownRunning = false;
        } else {
            countdownDeadline = Date.now() + countdownRemainingMs;
            countdownRunning = true;
        }
    }

    function resetCountdown() {
        countdownRunning = false;
        countdownDeadline = 0;
        countdownRemainingMs = countdownResetMs > 0 ? countdownResetMs : 5 * 60 * 1000;
    }

    property FileView uptimeFile: FileView {
        path: "/proc/uptime"
        printErrors: false
        onLoaded: {
            const seconds = Number(text().trim().split(/\s+/)[0]);
            if (isFinite(seconds)) {
                root.uptimeBaseSeconds = seconds;
                root.uptimeReadAt = Date.now();
            }
        }
    }

    property Timer clockTimer: Timer {
        interval: 100
        running: true
        repeat: true
        onTriggered: {
            root.timestamp = Date.now();
            root.now = new Date(root.timestamp);
            if (root.countdownRunning) {
                root.countdownRemainingMs = Math.max(0, root.countdownDeadline - root.timestamp);
                if (root.countdownRemainingMs <= 0) {
                    root.countdownRunning = false;
                    Quickshell.execDetached([
                        "notify-send",
                        "--app-name=Quickshell Clock",
                        "Countdown complete",
                        "The timer has finished."
                    ]);
                }
            }
        }
    }

    property Timer uptimeRefreshTimer: Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.uptimeFile.reload()
    }
}
