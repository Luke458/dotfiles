pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property var units: []
    property int total: 0
    property int healthy: 0
    property int failed: 0
    property int containers: 0
    property int runningContainers: 0
    property real totalCpu: 0
    property string totalMemory: "0B"
    property bool detailed: false
    property bool loading: true
    property string errorMessage: ""
    property date lastUpdated: new Date(0)
    property int detailsConsumers: 0
    property bool refreshQueued: false
    property bool queuedDetailed: false

    readonly property bool hasData: total > 0
    readonly property bool allHealthy: hasData && failed === 0

    Component.onCompleted: refresh(false)

    function beginDetails() {
        detailsConsumers += 1;
        refresh(true);
    }

    function endDetails() {
        detailsConsumers = Math.max(0, detailsConsumers - 1);
    }

    function refresh(includeStats = detailsConsumers > 0) {
        if (queryProc.running) {
            refreshQueued = true;
            queuedDetailed = queuedDetailed || includeStats;
            return;
        }

        loading = true;
        const command = [Quickshell.shellPath("scripts/quadlet-monitor")];
        if (includeStats)
            command.push("--stats");
        queryProc.exec(command);
    }

    function applyPayload(text) {
        try {
            const payload = JSON.parse(text);
            units = Array.isArray(payload.units) ? payload.units : [];
            total = Number(payload.total) || 0;
            healthy = Number(payload.healthy) || 0;
            failed = Number(payload.failed) || 0;
            containers = Number(payload.containers) || 0;
            runningContainers = Number(payload.runningContainers) || 0;
            totalCpu = Number(payload.totalCpu) || 0;
            totalMemory = payload.totalMemory || "0B";
            detailed = !!payload.detailed;
            errorMessage = payload.error || "";
            const timestamp = Number(payload.updatedAt);
            if (isFinite(timestamp) && timestamp > 0)
                lastUpdated = new Date(timestamp);
        } catch (error) {
            errorMessage = "Invalid quadlet monitor response";
        }
        loading = false;

        if (refreshQueued) {
            const includeStats = queuedDetailed || detailsConsumers > 0;
            refreshQueued = false;
            queuedDetailed = false;
            Qt.callLater(() => root.refresh(includeStats));
        }
    }

    property Timer refreshTimer: Timer {
        interval: root.detailsConsumers > 0 ? 5000 : 30000
        repeat: true
        running: true
        onTriggered: root.refresh(root.detailsConsumers > 0)
    }

    property Process queryProc: Process {
        stdout: StdioCollector {
            id: stdoutCollector
            onStreamFinished: root.applyPayload(text)
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const message = text.trim();
                if (message && !root.hasData)
                    root.errorMessage = message;
            }
        }

        onRunningChanged: {
            if (!running && root.loading && stdoutCollector.text.trim() === "") {
                root.loading = false;
                if (!root.errorMessage)
                    root.errorMessage = "Quadlet monitor did not return data";
            }
        }
    }
}
