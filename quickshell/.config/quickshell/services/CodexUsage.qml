pragma Singleton

import QtQuick
import Quickshell.Io

QtObject {
    id: root

    readonly property bool hasData: windows.length > 0
    readonly property var headlineWindow: hasData ? windows[headlineIndex] : null
    readonly property int remainingPercent: headlineWindow ? headlineWindow.remainingPercent : 0

    property bool initialized: false
    property bool loading: true
    property bool hasError: false
    property bool stale: false
    property string errorMessage: ""
    property string planType: ""
    property string rateLimitReachedType: ""
    property var windows: []
    property int headlineIndex: 0

    property bool hasCredits: false
    property bool creditsUnlimited: false
    property string creditBalance: ""

    property real lifetimeTokens: -1
    property real peakDailyTokens: -1
    property int currentStreakDays: -1
    property int longestStreakDays: -1
    property var recentDailyUsage: []
    property date lastUpdated: new Date(0)

    property int nextRequestId: 1
    property var pendingRequests: ({})
    property int pendingCount: 0
    property bool restartScheduled: false

    Component.onCompleted: {
        root.server.running = true;
        root.initializeTimer.restart();
    }

    function boundedPercent(value) {
        const number = Number(value);
        return isFinite(number) ? Math.max(0, Math.min(100, Math.round(number))) : 0;
    }

    function formatPlan(value) {
        if (!value)
            return "";
        return String(value).replace(/_/g, " ").replace(/\b\w/g, letter => letter.toUpperCase());
    }

    function genericWindowLabel(window) {
        const duration = Number(window && window.windowDurationMins);
        if (duration === 300)
            return "SESSION";
        if (duration === 1440)
            return "DAILY";
        if (duration === 10080)
            return "WEEKLY";
        if (duration > 0) {
            if (duration % 10080 === 0)
                return (duration / 10080) + ((duration / 10080) === 1 ? " WEEK" : " WEEKS");
            if (duration % 1440 === 0)
                return (duration / 1440) + ((duration / 1440) === 1 ? " DAY" : " DAYS");
            if (duration % 60 === 0)
                return (duration / 60) + ((duration / 60) === 1 ? " HOUR" : " HOURS");
        }
        return "USAGE";
    }

    function windowLabel(limitId, limitName, lane, window) {
        const generic = genericWindowLabel(window);
        if (limitId && limitId !== "codex") {
            const name = limitName || String(limitId).replace(/[-_]/g, " ");
            return name.toUpperCase() + " · " + generic;
        }
        if (limitName)
            return String(limitName).toUpperCase() + (lane === "secondary" ? " · " + generic : "");
        return generic;
    }

    function appendWindow(rows, limitId, snapshot, lane) {
        const window = snapshot ? snapshot[lane] : null;
        if (!window)
            return;

        const used = boundedPercent(window.usedPercent);
        const resetSeconds = Number(window.resetsAt);
        rows.push({
            id: (limitId || "codex") + "-" + lane,
            label: windowLabel(limitId, snapshot.limitName, lane, window),
            usedPercent: used,
            remainingPercent: 100 - used,
            windowDurationMins: Number(window.windowDurationMins) || 0,
            resetsAtMs: isFinite(resetSeconds) && resetSeconds > 0 ? resetSeconds * 1000 : 0
        });
    }

    function applyRateLimits(result) {
        const rows = [];
        const buckets = result.rateLimitsByLimitId;
        const bucketKeys = buckets ? Object.keys(buckets) : [];

        if (bucketKeys.length > 0) {
            bucketKeys.sort((left, right) => {
                if (left === right)
                    return 0;
                return left === "codex" ? -1 : (right === "codex" ? 1 : left.localeCompare(right));
            });
            for (const key of bucketKeys) {
                const snapshot = buckets[key];
                appendWindow(rows, key, snapshot, "primary");
                appendWindow(rows, key, snapshot, "secondary");
            }
        } else if (result.rateLimits) {
            appendWindow(rows, result.rateLimits.limitId || "codex", result.rateLimits, "primary");
            appendWindow(rows, result.rateLimits.limitId || "codex", result.rateLimits, "secondary");
        }

        const accountSnapshot = result.rateLimits || (buckets ? buckets.codex : null);
        if (accountSnapshot) {
            root.planType = root.formatPlan(accountSnapshot.planType);
            root.rateLimitReachedType = accountSnapshot.rateLimitReachedType || "";
            const credits = accountSnapshot.credits;
            root.hasCredits = !!(credits && credits.hasCredits);
            root.creditsUnlimited = !!(credits && credits.unlimited);
            root.creditBalance = credits && credits.balance !== null && credits.balance !== undefined
                ? String(credits.balance)
                : "";
        }

        let highestIndex = 0;
        for (let index = 1; index < rows.length; index++) {
            if (rows[index].usedPercent > rows[highestIndex].usedPercent)
                highestIndex = index;
        }

        root.windows = rows;
        root.headlineIndex = highestIndex;
        root.loading = false;
        root.hasError = rows.length === 0;
        root.stale = false;
        root.errorMessage = rows.length === 0 ? "Codex returned no usage windows" : "";
        root.lastUpdated = new Date();
    }

    function applyTokenUsage(result) {
        const summary = result.summary || {};
        root.lifetimeTokens = summary.lifetimeTokens === null || summary.lifetimeTokens === undefined
            ? -1 : Number(summary.lifetimeTokens);
        root.peakDailyTokens = summary.peakDailyTokens === null || summary.peakDailyTokens === undefined
            ? -1 : Number(summary.peakDailyTokens);
        root.currentStreakDays = summary.currentStreakDays === null || summary.currentStreakDays === undefined
            ? -1 : Number(summary.currentStreakDays);
        root.longestStreakDays = summary.longestStreakDays === null || summary.longestStreakDays === undefined
            ? -1 : Number(summary.longestStreakDays);

        const buckets = result.dailyUsageBuckets || [];
        const start = Math.max(0, buckets.length - 7);
        const recent = [];
        for (let index = start; index < buckets.length; index++) {
            recent.push({
                startDate: buckets[index].startDate,
                tokens: Number(buckets[index].tokens) || 0
            });
        }
        root.recentDailyUsage = recent;
    }

    function sendNotification(method, params) {
        if (!server.running)
            return;
        const message = { method: method };
        if (params !== undefined)
            message.params = params;
        server.write(JSON.stringify(message) + "\n");
    }

    function sendRequest(method, params, requestType) {
        if (!server.running)
            return -1;

        const requestId = root.nextRequestId++;
        const message = { id: requestId, method: method };
        if (params !== undefined)
            message.params = params;
        root.pendingRequests[String(requestId)] = requestType;
        root.pendingCount++;
        server.write(JSON.stringify(message) + "\n");
        requestWatchdog.restart();
        return requestId;
    }

    function finishRequest(requestId) {
        const key = String(requestId);
        const requestType = root.pendingRequests[key];
        if (requestType === undefined)
            return "";
        delete root.pendingRequests[key];
        root.pendingCount = Math.max(0, root.pendingCount - 1);
        if (root.pendingCount === 0)
            requestWatchdog.stop();
        return requestType;
    }

    function beginInitialize() {
        if (!server.running || root.initialized || root.pendingCount > 0)
            return;
        root.initialized = false;
        root.sendRequest("initialize", {
            clientInfo: {
                name: "quickshell-codex-usage",
                version: "1.0"
            }
        }, "initialize");
    }

    function refresh() {
        if (!root.initialized) {
            if (!server.running && !root.restartScheduled)
                server.running = true;
            return;
        }
        if (root.pendingCount > 0)
            return;

        root.loading = true;
        root.sendRequest("account/rateLimits/read", undefined, "rateLimits");
        root.sendRequest("account/usage/read", undefined, "tokenUsage");
    }

    function handleResponseError(requestType, error) {
        const message = error && error.message ? error.message : "Codex request failed";
        if (requestType === "initialize") {
            root.scheduleRestart(message);
            return;
        }
        if (requestType === "rateLimits") {
            root.loading = false;
            root.hasError = !root.hasData;
            root.stale = root.hasData;
            root.errorMessage = message;
        }
    }

    function handleLine(data) {
        const line = data.trim();
        if (!line)
            return;

        let message;
        try {
            message = JSON.parse(line);
        } catch (error) {
            return;
        }

        if (message.id !== undefined) {
            const requestType = root.finishRequest(message.id);
            if (!requestType)
                return;
            if (message.error) {
                root.handleResponseError(requestType, message.error);
                return;
            }

            if (requestType === "initialize") {
                root.initialized = true;
                root.hasError = false;
                root.errorMessage = "";
                root.sendNotification("initialized");
                root.refresh();
            } else if (requestType === "rateLimits") {
                root.applyRateLimits(message.result || {});
            } else if (requestType === "tokenUsage") {
                root.applyTokenUsage(message.result || {});
            }
            return;
        }

        if (message.method === "account/rateLimits/updated")
            rollingUpdateTimer.restart();
    }

    // Exponential backoff for app-server restarts (e.g. while `codex` is
    // missing), reset whenever a start succeeds.
    property int restartBackoffMs: 30000

    function scheduleRestart(message) {
        root.initialized = false;
        root.loading = !root.hasData;
        root.hasError = !root.hasData;
        root.stale = root.hasData;
        root.errorMessage = message || "Codex app-server stopped";
        root.pendingRequests = ({});
        root.pendingCount = 0;
        requestWatchdog.stop();
        root.restartScheduled = true;

        if (server.running) {
            server.running = false; // backoff applied in onRunningChanged
        } else {
            root.restartTimer.interval = root.restartBackoffMs;
            root.restartBackoffMs = Math.min(root.restartBackoffMs * 2, 600000);
            restartTimer.restart();
        }
    }

    property Process server: Process {
        // codex-cli 0.149.0 removed the "untrusted" approval policy; the
        // app-server here only answers read-only RPCs, so "never" is the
        // equivalent-safe choice.
        command: ["codex", "-s", "read-only", "-a", "never", "app-server", "--stdio"]
        stdinEnabled: true
        running: false

        stdout: SplitParser {
            onRead: data => root.handleLine(data)
        }

        stderr: SplitParser {
            // Diagnostics can contain account-related detail, so keep them out of shell logs.
            onRead: data => {}
        }

        onStarted: {
            root.restartScheduled = false;
            root.initializeTimer.restart();
        }

        onRunningChanged: {
            if (running) {
                root.restartBackoffMs = 30000;
                root.initializeTimer.restart();
            } else {
                root.restartTimer.interval = root.restartBackoffMs;
                root.restartBackoffMs = Math.min(root.restartBackoffMs * 2, 600000);
                if (!root.restartScheduled)
                    root.scheduleRestart("Could not read Codex usage");
                else
                    root.restartTimer.restart();
            }
        }
    }

    property Timer requestWatchdog: Timer {
        interval: 15000
        repeat: false
        onTriggered: root.scheduleRestart("Codex usage request timed out")
    }

    property Timer initializeTimer: Timer {
        interval: 750
        repeat: false
        onTriggered: root.beginInitialize()
    }

    property Timer restartTimer: Timer {
        repeat: false
        onTriggered: {
            root.restartScheduled = false;
            if (!root.server.running)
                root.server.running = true;
        }
    }

    property Timer refreshTimer: Timer {
        interval: 300000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    property Timer rollingUpdateTimer: Timer {
        interval: 1500
        repeat: false
        onTriggered: {
            if (root.pendingCount > 0)
                restart();
            else
                root.refresh();
        }
    }
}
