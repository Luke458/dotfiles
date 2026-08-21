pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string commandPath: Quickshell.env("SBR_PATH") || "/home/luke/Projects/sing-box-routes/bin/sbr"

    property var routes: []
    property int total: 0
    property bool loading: true
    property bool busy: false
    property bool liveWritable: false
    property bool liveSynchronized: false
    property bool mainConfigSynchronized: false
    property bool bypassConfigSynchronized: false
    property bool systemdSynchronized: false
    property bool deploymentSynchronized: false
    property string mainServiceState: "unknown"
    property string bypassServiceState: "unknown"
    property string errorMessage: ""
    property string lastMessage: ""
    property string sourceDir: ""
    property string liveRuleSetDir: ""
    property date lastUpdated: new Date(0)
    property int detailsConsumers: 0
    property bool refreshQueued: false
    property string actionName: ""

    readonly property bool mainActive: mainServiceState === "active"
    readonly property bool bypassActive: bypassServiceState === "active"
    readonly property bool active: mainActive && bypassActive
    readonly property bool healthy: active && liveSynchronized
        && deploymentSynchronized && errorMessage.length === 0

    Component.onCompleted: refresh()

    function beginDetails() {
        detailsConsumers += 1;
        refresh();
    }

    function endDetails() {
        detailsConsumers = Math.max(0, detailsConsumers - 1);
    }

    function routeLabel(name) {
        if (name === "bypass")
            return "BYPASS";
        if (name === "mullvad-sg")
            return "MULLVAD SG";
        return String(name || "ROUTE").replace(/-/g, " ").toUpperCase();
    }

    function refresh() {
        if (busy || listProc.running) {
            refreshQueued = true;
            return;
        }

        loading = true;
        errorMessage = "";
        listProc.exec([commandPath, "list", "--json"]);
        if (!serviceProc.running)
            serviceProc.exec([
                "systemctl", "is-active",
                "sing-box.service", "sing-box-bypass.service"
            ]);
    }

    function runAction(argumentsList, name) {
        if (busy || actionProc.running)
            return;

        const command = [commandPath];
        for (let i = 0; i < argumentsList.length; i++)
            command.push(String(argumentsList[i]));

        busy = true;
        actionName = name;
        errorMessage = "";
        lastMessage = "";
        actionProc.exec(command);
    }

    function addEntry(route, entry) {
        const value = String(entry || "").trim();
        if (value.length === 0) {
            errorMessage = "Enter a domain, URL, exact match, keyword, regex, or IP range.";
            return;
        }
        runAction(["add", route, value], "Adding route");
    }

    function removeEntry(route, entry) {
        runAction(["remove", route, entry], "Removing route");
    }

    function validateAndApply() {
        runAction(["apply"], "Validating routes");
    }

    function applyPayload(text) {
        try {
            const payload = JSON.parse(String(text || "").trim());
            routes = Array.isArray(payload.routes) ? payload.routes : [];
            total = Number(payload.total) || 0;
            liveWritable = !!payload.liveWritable;
            liveSynchronized = !!payload.liveSynchronized;
            mainConfigSynchronized = !!payload.mainConfigSynchronized;
            bypassConfigSynchronized = !!payload.bypassConfigSynchronized;
            systemdSynchronized = !!payload.systemdSynchronized;
            deploymentSynchronized = !!payload.deploymentSynchronized;
            sourceDir = payload.sourceDir || "";
            liveRuleSetDir = payload.liveRuleSetDir || "";
            lastUpdated = new Date();
        } catch (error) {
            errorMessage = "Invalid response from sbr";
        }
    }

    property Timer refreshTimer: Timer {
        interval: root.detailsConsumers > 0 ? 15000 : 120000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    property Process listProc: Process {
        stdout: StdioCollector { id: listStdout }
        stderr: StdioCollector { id: listStderr }

        onExited: exitCode => { // qmllint disable signal-handler-parameters
            root.loading = false;
            if (exitCode === 0 && listStdout.text.trim().length > 0) {
                root.applyPayload(listStdout.text);
            } else if (exitCode === 0) {
                // An empty "success" must not leave stale routes presented
                // as fresh data with no error indication.
                root.errorMessage = "sbr returned no route data";
            } else {
                root.errorMessage = listStderr.text.trim() || "Could not read sing-box routes";
            }

            if (root.refreshQueued && !root.busy) {
                root.refreshQueued = false;
                Qt.callLater(() => root.refresh());
            }
        }
    }

    property Process serviceProc: Process {
        stdout: StdioCollector { id: serviceStdout }
        stderr: StdioCollector {}

        onExited: exitCode => { // qmllint disable signal-handler-parameters
            const states = serviceStdout.text.trim().split(/\s+/);
            root.mainServiceState = states.length > 0 && states[0].length > 0
                ? states[0] : "unknown";
            root.bypassServiceState = states.length > 1 && states[1].length > 0
                ? states[1] : "unknown";
        }
    }

    property Process actionProc: Process {
        stdout: StdioCollector { id: actionStdout }
        stderr: StdioCollector { id: actionStderr }

        onExited: exitCode => { // qmllint disable signal-handler-parameters
            root.busy = false;
            if (exitCode === 0) {
                root.lastMessage = actionStdout.text.trim() || root.actionName + " complete";
            } else {
                root.errorMessage = actionStderr.text.trim() || actionStdout.text.trim() || root.actionName + " failed";
            }
            root.actionName = "";
            root.refresh();
        }
    }
}
