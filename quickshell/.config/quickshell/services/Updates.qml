pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    property var sources: ({})
    property var items: []
    property int total: 0
    property int lastChecked: 0
    property date nextCheck: new Date(0)
    property bool checking: false
    property string actionError: ""
    property string lastAction: ""
    readonly property bool launching: actionProc.running
    readonly property bool hasErrors: ["packages", "aur", "mise"].some(source => sourceError(source) !== "")
    readonly property string summary: checking ? "Checking for updates…"
        : hasErrors ? "Check incomplete · results may be out of date"
        : total > 0 ? total + (total === 1 ? " update available" : " updates available")
        : "Everything is up to date"

    function count(source) {
        const entry = sources[source];
        return entry && Array.isArray(entry.items) ? entry.items.length : 0;
    }

    function sourceError(source) {
        const entry = sources[source];
        return entry ? (entry.error || "") : "Not checked";
    }

    function apply(payloadText, isCheck) {
        try {
            const payload = JSON.parse(payloadText);
            if (!payload.sources)
                throw new Error(payload.error || "Invalid update response");
            const previousTotal = total;
            const hadCheck = lastChecked > 0;
            sources = { packages: payload.sources.packages, aur: payload.sources.aur, mise: payload.sources.mise };
            let entries = [];
            let timestamp = 0;
            for (const source of ["packages", "aur", "mise"]) {
                const item = sources[source];
                if (!item)
                    continue;
                entries = entries.concat(Array.isArray(item.items) ? item.items : []);
                timestamp = Math.max(timestamp, Number(item.checkedAt) || 0);
            }
            items = entries;
            total = entries.length;
            lastChecked = timestamp;
            if (isCheck && hadCheck && total > previousTotal)
                Quickshell.execDetached(["notify-send", "Updates available", total + " updates available"]);
        } catch (error) {
            actionError = "Update status: " + error;
        }
        if (isCheck) {
            checking = false;
            nextCheck = new Date(Date.now() + checkTimer.interval);
            checkTimer.restart();
        }
    }

    function refresh() {
        if (checkProc.running) return;
        checkTimer.stop();
        checking = true;
        checkProc.exec([Quickshell.shellPath("scripts/update-monitor"), "check"]);
    }

    function launch(source) {
        if (actionProc.running) return;
        actionError = "";
        lastAction = "";
        actionProc.exec([Quickshell.shellPath("scripts/update-monitor"), "launch", source]);
    }

    property Process cacheProc: Process {
        stdout: StdioCollector {
            onStreamFinished: root.apply(text, false)
        }
    }

    property Process checkProc: Process {
        stdout: StdioCollector {
            onStreamFinished: root.apply(text, true)
        }
    }

    property Process actionProc: Process {
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const payload = JSON.parse(text);
                    root.actionError = payload.error || "";
                    root.lastAction = payload.launched || "";
                } catch (error) {
                    root.actionError = "Could not launch updater";
                }
            }
        }
    }

    property Timer checkTimer: Timer {
        interval: 30 * 60 * 1000
        running: false
        repeat: false
        onTriggered: root.refresh()
    }

    property Timer startupTimer: Timer {
        interval: 2000
        running: true
        repeat: false
        onTriggered: root.refresh()
    }

    Component.onCompleted: cacheProc.exec([Quickshell.shellPath("scripts/update-monitor"), "status"])
}
