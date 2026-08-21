pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property bool available: false
    property string sessionState: "UNKNOWN"
    property bool sessionRunning: false
    property string containerState: "UNKNOWN"
    property string containerServiceState: "unknown"
    property string containerServiceSubState: "unknown"
    property bool serviceActive: false
    property bool containerRunning: false
    property string vendorType: ""
    property string ipAddress: ""
    property string sessionUser: ""
    property string waylandDisplay: ""
    property var apps: []
    property int appCount: 0
    property bool loading: true
    property string errorMessage: ""
    property string lastMessage: ""
    property string actionName: ""
    property date lastUpdated: new Date(0)
    property int detailsConsumers: 0
    property bool refreshQueued: false
    property bool launching: false
    property var deferredCommand: []

    readonly property bool busy: actionProc.running || launching

    Component.onCompleted: refresh()

    function beginDetails() {
        detailsConsumers += 1;
        refresh();
    }

    function endDetails() {
        detailsConsumers = Math.max(0, detailsConsumers - 1);
    }

    function refresh() {
        if (queryProc.running) {
            refreshQueued = true;
            return;
        }
        loading = true;
        queryProc.exec([Quickshell.shellPath("scripts/waydroid-monitor")]);
    }

    function applyPayload(text) {
        try {
            const payload = JSON.parse(String(text || "").trim());
            available = !!payload.available;
            sessionState = payload.sessionState || "UNKNOWN";
            sessionRunning = !!payload.sessionRunning;
            containerState = payload.containerState || "UNKNOWN";
            containerServiceState = payload.containerServiceState || "unknown";
            containerServiceSubState = payload.containerServiceSubState || "unknown";
            serviceActive = !!payload.serviceActive;
            containerRunning = !!payload.containerRunning;
            vendorType = payload.vendorType || "";
            ipAddress = payload.ipAddress || "";
            sessionUser = payload.sessionUser || "";
            waylandDisplay = payload.waylandDisplay || "";
            apps = Array.isArray(payload.apps) ? payload.apps : [];
            appCount = Number(payload.appCount) || apps.length;
            errorMessage = payload.error || "";
            const timestamp = Number(payload.updatedAt);
            if (isFinite(timestamp) && timestamp > 0)
                lastUpdated = new Date(timestamp);
            if (sessionRunning)
                launching = false;
        } catch (error) {
            errorMessage = "Invalid Waydroid monitor response";
        }
        loading = false;
    }

    function runAction(command, label, commandAfter = []) {
        if (busy)
            return;
        actionName = label;
        lastMessage = "";
        errorMessage = "";
        deferredCommand = commandAfter;
        actionProc.exec(command);
    }

    function runDetached(command, label) {
        if (busy)
            return;
        actionName = label;
        lastMessage = label + "…";
        errorMessage = "";
        launching = true;
        Quickshell.execDetached(command);
        launchSettleTimer.restart();
        refreshDelay.restart();
    }

    function ensureContainerThen(command, label) {
        if (serviceActive) {
            runDetached(command, label);
            return;
        }
        runAction(
            ["pkexec", "systemctl", "start", "waydroid-container.service"],
            "Starting container",
            command
        );
        actionName = label;
    }

    function startService() {
        // pkexec is handled by the shell's registered Polkit agent.
        runAction(["pkexec", "systemctl", "start", "waydroid-container.service"], "Starting Waydroid service");
    }

    function stopService() {
        runAction(["pkexec", "systemctl", "stop", "waydroid-container.service"], "Stopping Waydroid service");
    }

    function startSession() {
        ensureContainerThen(["waydroid", "session", "start"], "Starting session");
    }

    function stopSession() {
        runAction(["waydroid", "session", "stop"], "Stopping session");
    }

    function showFullUi() {
        ensureContainerThen(["waydroid", "show-full-ui"], "Opening full UI");
    }

    function launchApp(packageName) {
        const value = String(packageName || "");
        if (!apps.some(app => app.packageName === value)) {
            errorMessage = "Unknown Waydroid application";
            return;
        }
        ensureContainerThen(["waydroid", "app", "launch", value], "Launching application");
    }

    property Timer refreshTimer: Timer {
        // Fast while a details popup consumes data; otherwise a slow
        // background poll just keeps the bar indicator honest.
        interval: root.detailsConsumers > 0 ? 5000 : 60000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    property Timer refreshDelay: Timer {
        interval: 900
        repeat: false
        onTriggered: root.refresh()
    }

    property Timer launchPollTimer: Timer {
        interval: 1000
        repeat: true
        running: root.launching
        onTriggered: root.refresh()
    }

    property Timer launchSettleTimer: Timer {
        interval: 10000
        repeat: false
        onTriggered: {
            root.launching = false;
            root.actionName = "";
            root.refresh();
        }
    }

    property Process queryProc: Process {
        stdout: StdioCollector { id: queryStdout }
        stderr: StdioCollector { id: queryStderr }

        onExited: exitCode => { // qmllint disable signal-handler-parameters
            root.loading = false;
            if (exitCode === 0 && queryStdout.text.trim().length > 0) {
                root.applyPayload(queryStdout.text);
            } else {
                root.errorMessage = queryStderr.text.trim() || "Could not inspect Waydroid";
            }
            if (root.refreshQueued) {
                root.refreshQueued = false;
                Qt.callLater(() => root.refresh());
            }
        }
    }

    property Process actionProc: Process {
        stdout: StdioCollector { id: actionStdout }
        stderr: StdioCollector { id: actionStderr }

        onExited: exitCode => { // qmllint disable signal-handler-parameters
            const followup = root.deferredCommand;
            root.deferredCommand = [];
            if (exitCode === 0) {
                if (followup.length > 0) {
                    root.runDetached(followup, root.actionName);
                } else {
                    root.lastMessage = root.actionName + " complete";
                    root.actionName = "";
                    root.refreshDelay.restart();
                }
            } else {
                root.errorMessage = actionStderr.text.trim() || actionStdout.text.trim() || root.actionName + " failed";
                root.actionName = "";
                root.refresh();
            }
        }
    }
}
