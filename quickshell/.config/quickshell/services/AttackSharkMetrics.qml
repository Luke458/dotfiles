pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property bool connected: false
    property bool loading: true
    property bool stale: true
    property bool hasError: false
    property int battery: -1
    property string device: ""
    property string errorMessage: ""
    property date lastUpdated: new Date(0)

    readonly property bool hasBattery: battery >= 0 && battery <= 100

    Component.onCompleted: monitor.running = true

    function applyLine(data) {
        const line = data.trim();
        if (!line)
            return;

        try {
            const message = JSON.parse(line);
            root.connected = !!message.connected;
            root.stale = message.stale === undefined ? root.stale : !!message.stale;
            root.device = message.device || "";
            root.errorMessage = message.error || "";
            root.hasError = root.errorMessage.length > 0;

            if (message.battery !== null && message.battery !== undefined) {
                const value = Number(message.battery);
                if (isFinite(value) && value >= 0 && value <= 100)
                    root.battery = Math.round(value);
            }

            const updatedAt = Number(message.updated_at);
            if (isFinite(updatedAt) && updatedAt > 0)
                root.lastUpdated = new Date(updatedAt * 1000);

            root.loading = false;
        } catch (error) {
            root.hasError = true;
            root.errorMessage = "Invalid mouse metrics response";
            root.loading = false;
        }
    }

    function refresh() {
        root.loading = !root.hasBattery;
        if (monitor.running)
            monitor.running = false;
        else
            root.restartTimer.restart();
    }

    property Process monitor: Process {
        command: [Quickshell.shellPath("scripts/attack-shark-metrics")]

        stdout: SplitParser {
            onRead: data => root.applyLine(data)
        }

        stderr: SplitParser {
            onRead: data => {
                const message = data.trim();
                if (message) {
                    root.hasError = true;
                    root.errorMessage = message;
                    root.loading = false;
                }
            }
        }

        onRunningChanged: {
            if (running)
                return;
            root.connected = false;
            root.stale = root.hasBattery;
            root.restartTimer.restart();
        }
    }

    property Timer restartTimer: Timer {
        interval: 3000
        repeat: false
        onTriggered: {
            if (!root.monitor.running)
                root.monitor.running = true;
        }
    }
}
