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
    // USB-C cable attached (the mouse enumerates as 372e:1015).
    property bool wired: false
    // Charging flag (bit 7 of the battery byte) from the cabled mouse.
    property bool charging: false
    // Link of the interface being read: "wired", "wireless", or "".
    property string mode: ""
    property int battery: -1
    property string device: ""
    property string errorMessage: ""
    property date lastUpdated: new Date(0)

    readonly property bool hasBattery: battery >= 0 && battery <= 100

    // DPI needs active feature-report traffic to the mouse, unlike the
    // passive battery heartbeat, so it is only queried while the details
    // flyout is open and after a stage change.
    property var dpiStages: []
    property int dpiActiveStage: -1
    property string dpiMode: ""
    property bool dpiLoading: false
    property string dpiError: ""
    property bool dpiRefreshQueued: false
    property bool awaitingDpiStart: false
    property string lastDpiReport: ""
    property int detailsConsumers: 0
    property var firmwareInfo: null
    property bool firmwareLoading: false
    property string firmwareError: ""
    property bool awaitingFirmwareStart: false
    property int deviceGeneration: 0
    property int firmwareGeneration: -1

    readonly property bool hasDpi: dpiStages.length > 0 && dpiActiveStage >= 1
    readonly property int activeDpi: hasDpi && dpiActiveStage <= dpiStages.length ? dpiStages[dpiActiveStage - 1] : -1

    Component.onCompleted: startMonitor()

    function beginDetails() {
        detailsConsumers += 1;
        refreshDpi();
    }

    function endDetails() {
        detailsConsumers = Math.max(0, detailsConsumers - 1);
    }

    function refreshDpi() {
        if (dpiProc.running) {
            dpiRefreshQueued = true;
            return;
        }
        runDpi(["status"]);
    }

    function selectDpiStage(stage) {
        if (!connected || dpiLoading || stage === dpiActiveStage || !(stage >= 1 && stage <= 8))
            return;
        runDpi(["select", String(stage), "--apply"]);
    }

    function setDpi(stage, dpi) {
        if (!connected || dpiLoading || !Number.isInteger(stage) || stage < 1 || stage > 8
                || !Number.isInteger(dpi) || dpi < 50 || dpi > 30000 || dpi % 50 !== 0)
            return;
        runDpi(["set", String(dpi), "--stage", String(stage), "--apply"]);
    }

    function clearDpi() {
        dpiStages = [];
        dpiActiveStage = -1;
        dpiMode = "";
        lastDpiReport = "";
    }

    function checkDpiStartFailure() {
        if (dpiProc.running || !awaitingDpiStart)
            return;
        awaitingDpiStart = false;
        dpiLoading = false;
        dpiError = "Could not start " + dpiProc.command[0];
    }

    function runDpi(args) {
        if (dpiLoading)
            return;
        dpiLoading = true;
        awaitingDpiStart = true;
        dpiProc.exec([Quickshell.shellPath("scripts/attack-shark-dpi"), "--json"].concat(args));
        Qt.callLater(checkDpiStartFailure);
    }

    function clearFirmware() {
        deviceGeneration += 1;
        firmwareInfo = null;
        firmwareError = "";
    }

    function refreshFirmware() {
        if (!connected || firmwareLoading || dpiLoading)
            return;
        firmwareInfo = null;
        firmwareError = "";
        firmwareLoading = true;
        awaitingFirmwareStart = true;
        firmwareGeneration = deviceGeneration;
        firmwareProc.exec([Quickshell.shellPath("scripts/attack-shark-dpi"), "--json", "firmware"]);
        Qt.callLater(checkFirmwareStartFailure);
    }

    function checkFirmwareStartFailure() {
        if (firmwareProc.running || !awaitingFirmwareStart)
            return;
        awaitingFirmwareStart = false;
        firmwareLoading = false;
        if (firmwareGeneration === deviceGeneration)
            firmwareError = "Could not start " + firmwareProc.command[0];
    }

    function applyFirmwarePayload(text) {
        firmwareInfo = null;
        try {
            const payload = JSON.parse(String(text || "").trim());
            if (payload.error) {
                firmwareError = String(payload.error);
                return;
            }
            const status = payload.firmware_status;
            const version = payload.firmware_version;
            if (payload.family !== "PIAO" || payload.device_uuid !== "090000000005"
                    || payload.firmware_update_supported !== false
                    || !["requires_usb", "detected", "unavailable"].includes(status)
                    || typeof payload.firmware_message !== "string"
                    || typeof payload.firmware_update_reason !== "string"
                    || (status === "detected" ? typeof version !== "string" || !/^[0-9a-f]{4}$/.test(version)
                        || version === "0000" || version === "ffff" : version !== null)
                    || (payload.mode === "wireless" ? status !== "requires_usb" || payload.usb_id !== "372e:1014"
                        : payload.mode !== "wired" || status === "requires_usb" || payload.usb_id !== "372e:1015"))
                throw new Error("bad payload");
            if (!connected || payload.device !== device || payload.mode !== mode) {
                firmwareError = "Mouse connection changed; read firmware again";
                return;
            }
            firmwareInfo = payload;
            firmwareError = "";
        } catch (error) {
            firmwareError = "Invalid firmware response";
        }
    }

    // Passive stage-change notification from the metrics stream (DPI button
    // presses included), so the flyout stays current without re-querying.
    function applyDpiChange(stage, dpi) {
        if (!(stage >= 1 && stage <= 8 && dpi > 0))
            return;
        if (dpiStages.length >= stage && dpiStages[stage - 1] !== dpi) {
            const stages = dpiStages.slice();
            stages[stage - 1] = dpi;
            dpiStages = stages;
        }
        dpiActiveStage = stage;
    }

    function applyDpiPayload(text) {
        try {
            const payload = JSON.parse(String(text || "").trim());
            if (payload.error) {
                dpiError = String(payload.error);
                return;
            }
            const stages = Array.isArray(payload.stages) ? payload.stages.map(Number) : [];
            const active = Number(payload.active_stage);
            if (stages.length !== 8 || !stages.every(value => Number.isInteger(value) && value >= 50 && value <= 30000 && value % 50 === 0)
                    || !Number.isInteger(active) || !(active >= 1 && active <= stages.length))
                throw new Error("bad payload");
            dpiStages = stages;
            dpiActiveStage = active;
            dpiMode = payload.mode || "";
            dpiError = "";
        } catch (error) {
            dpiError = "Invalid DPI response";
        }
    }

    function applyLine(data) {
        const line = data.trim();
        if (!line)
            return;

        try {
            const message = JSON.parse(line);
            const linkChanged = root.device !== (message.device || "") || root.connected !== !!message.connected
                || root.mode !== (message.mode || "");
            if (linkChanged) {
                root.clearDpi();
                root.clearFirmware();
            }
            root.connected = !!message.connected;
            root.wired = !!message.wired;
            root.charging = !!message.charging;
            root.mode = message.mode || "";
            root.stale = message.stale === undefined ? root.stale : !!message.stale;
            root.device = message.device || "";
            root.errorMessage = message.error || "";
            root.hasError = root.errorMessage.length > 0;

            if (message.battery === null) {
                root.battery = -1;
            } else if (message.battery !== undefined) {
                const value = Number(message.battery);
                if (isFinite(value) && value >= 0 && value <= 100)
                    root.battery = Math.round(value);
            }

            const dpiReport = message.dpi_stage == null ? "" : String(message.dpi_stage) + ":" + String(message.dpi);
            if (root.connected && dpiReport && dpiReport !== root.lastDpiReport)
                root.applyDpiChange(Number(message.dpi_stage), Number(message.dpi));
            root.lastDpiReport = dpiReport;
            if (linkChanged && root.connected && root.detailsConsumers > 0)
                root.refreshDpi();

            const updatedAt = Number(message.updated_at);
            if (isFinite(updatedAt) && updatedAt > 0)
                root.lastUpdated = new Date(updatedAt * 1000);
            else
                root.lastUpdated = new Date(0);

            root.loading = false;
        } catch (error) {
            root.hasError = true;
            root.errorMessage = "Invalid mouse metrics response";
            root.loading = false;
        }
    }

    function refresh() {
        // The helper streams updates on its own; killing and relaunching it
        // would only open a data gap. Ensure it runs and let the stream
        // deliver the next sample.
        root.loading = !root.hasBattery;
        startMonitor();
    }

    // Single entry point for every start, so the "binary could not be started"
    // case is always checked.
    function startMonitor() {
        if (monitor.running)
            return;
        root.awaitingStart = true;
        monitor.running = true;
        Qt.callLater(checkStartFailure);
    }

    // A helper that cannot be exec'd - missing, not executable, or a dangling
    // symlink such as scripts/attack-shark-metrics pointing outside this repo -
    // never reaches onExited, so `running` simply falls back to false within
    // the same tick. Without this the restart backoff would keep retrying a
    // command that can never start, forever, leaving the widget silently blank.
    function checkStartFailure() {
        if (monitor.running || !root.awaitingStart)
            return;
        root.awaitingStart = false;
        root.hasError = true;
        root.errorMessage = "Could not start " + monitor.command[0];
        root.loading = false;
    }

    // Exponential backoff while the helper keeps dying, reset on good data.
    property int restartBackoffMs: 3000
    property bool awaitingStart: false

    property Process monitor: Process {
        command: [Quickshell.shellPath("scripts/attack-shark-metrics")]

        stdout: SplitParser {
            onRead: data => {
                root.applyLine(data);
                root.restartBackoffMs = 3000;
            }
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

        onStarted: root.awaitingStart = false
        onExited: (exitCode, exitStatus) => { // qmllint disable signal-handler-parameters
            root.awaitingStart = false;
        }

        onRunningChanged: {
            if (running)
                return;
            // The exec failure is detected asynchronously, one turn after
            // startMonitor's own deferred check has already seen the process
            // still running, so re-check here where running is known false.
            root.checkStartFailure();
            root.connected = false;
            root.wired = false;
            root.charging = false;
            root.mode = "";
            root.stale = true;
            root.clearDpi();
            root.clearFirmware();
            root.restartTimer.interval = root.restartBackoffMs;
            root.restartBackoffMs = Math.min(root.restartBackoffMs * 2, 60000);
            root.restartTimer.restart();
        }
    }

    property Process dpiProc: Process {
        stdout: StdioCollector { id: dpiStdout }
        stderr: StdioCollector { id: dpiStderr }

        onStarted: root.awaitingDpiStart = false
        onRunningChanged: {
            if (!running)
                Qt.callLater(root.checkDpiStartFailure);
        }

        onExited: exitCode => { // qmllint disable signal-handler-parameters
            root.awaitingDpiStart = false;
            root.dpiLoading = false;
            const output = dpiStdout.text.trim();
            if (output)
                root.applyDpiPayload(output);
            else
                root.dpiError = dpiStderr.text.trim() || "DPI tool exited with code " + exitCode;
            if (!root.connected)
                root.clearDpi();
            const refresh = root.dpiRefreshQueued && root.detailsConsumers > 0 && root.connected;
            root.dpiRefreshQueued = false;
            if (refresh)
                Qt.callLater(() => root.refreshDpi());
        }
    }

    property Timer dpiRetryTimer: Timer {
        interval: 10000
        repeat: true
        running: root.detailsConsumers > 0 && root.connected && !root.dpiLoading && root.dpiError.length > 0
        onTriggered: root.refreshDpi()
    }

    property Process firmwareProc: Process {
        stdout: StdioCollector { id: firmwareStdout }
        stderr: StdioCollector { id: firmwareStderr }

        onStarted: root.awaitingFirmwareStart = false
        onRunningChanged: {
            if (!running)
                Qt.callLater(root.checkFirmwareStartFailure);
        }

        onExited: exitCode => {
            root.awaitingFirmwareStart = false;
            root.firmwareLoading = false;
            if (root.firmwareGeneration !== root.deviceGeneration || !root.connected)
                return;
            const output = firmwareStdout.text.trim();
            if (exitCode !== 0)
                root.firmwareError = firmwareStderr.text.trim() || "Firmware tool exited with code " + exitCode;
            if (output)
                root.applyFirmwarePayload(output);
            else if (exitCode === 0)
                root.firmwareError = "Empty firmware response";
        }
    }

    property Timer restartTimer: Timer {
        repeat: false
        onTriggered: root.startMonitor()
    }
}
