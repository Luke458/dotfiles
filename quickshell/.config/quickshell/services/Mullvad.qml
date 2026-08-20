pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property string state: "unknown"
    property string errorMessage: ""
    property bool daemonAvailable: true
    property bool lockedDown: false
    property bool commandRunning: commandProc.running

    property string country: ""
    property string countryCode: ""
    property string city: ""
    property string cityCode: ""
    property string hostname: ""
    property string entryHostname: ""
    property string visibleIp: ""
    property string locationName: ""
    property string lastUpdated: ""

    property string relayConstraint: ""
    property string relayConstraintLabel: "Any location"
    property bool locationsLoading: false
    property var countries: []
    property var locations: [{ kind: "any", label: "Any location", sublabel: "Automatic relay selection", countryCode: "", cityCode: "" }]
    property var countryNamesByCode: ({})
    property var cityNamesByKey: ({})

    property bool autoConnect: false
    property bool lanAllowed: false
    property bool lockdownMode: false
    property bool ipv6: false
    property bool quantumResistant: false
    property bool daita: false

    property string accountMasked: ""
    property string accountExpiry: ""
    property string deviceName: ""
    property string version: ""
    property bool supported: true

    property var pendingFollowUp: []
    property string lastCommandName: ""
    property string lastCommandError: ""

    readonly property bool connected: state === "connected"
    readonly property bool connecting: state === "connecting"
    readonly property bool disconnecting: state === "disconnecting"
    readonly property bool disconnected: state === "disconnected"
    readonly property bool hasError: !daemonAvailable || state === "error" || errorMessage.length > 0
    readonly property string stateLabel: {
        if (!daemonAvailable)
            return "DAEMON OFF";
        if (state === "connected")
            return "CONNECTED";
        if (state === "connecting")
            return "CONNECTING";
        if (state === "disconnecting")
            return "DISCONNECTING";
        if (state === "disconnected")
            return lockedDown || lockdownMode ? "LOCKED" : "DISCONNECTED";
        if (state === "error")
            return "ERROR";
        return "UNKNOWN";
    }
    readonly property string indicatorLabel: {
        if (!daemonAvailable)
            return "ERR";
        if (connected) {
            if (cityCode.length > 0)
                return cityCode.toUpperCase();
            if (countryCode.length > 0)
                return countryCode.toUpperCase();
            return "ON";
        }
        if (connecting || disconnecting)
            return "...";
        if (lockedDown || lockdownMode)
            return "LOCK";
        return "OFF";
    }
    readonly property string summary: {
        if (errorMessage.length > 0)
            return errorMessage;
        if (locationName.length > 0)
            return locationName + (visibleIp.length > 0 ? " - " + visibleIp : "");
        if (relayConstraintLabel.length > 0)
            return relayConstraintLabel;
        return "No location";
    }

    Component.onCompleted: {
        refreshAll();
        statusListenProc.running = true;
    }

    function refreshAll() {
        refreshStatus();
        refreshSettings();
        refreshAccount();
        refreshVersion();
        if (locations.length <= 1)
            refreshLocations();
    }

    function refreshStatus() {
        if (!statusProc.running)
            statusProc.exec(["mullvad", "status", "-j"]);
    }

    function refreshSettings() {
        if (!relayGetProc.running)
            relayGetProc.exec(["mullvad", "relay", "get"]);
        if (!autoProc.running)
            autoProc.exec(["mullvad", "auto-connect", "get"]);
        if (!lanProc.running)
            lanProc.exec(["mullvad", "lan", "get"]);
        if (!lockdownProc.running)
            lockdownProc.exec(["mullvad", "lockdown-mode", "get"]);
        if (!tunnelProc.running)
            tunnelProc.exec(["mullvad", "tunnel", "get"]);
    }

    function refreshLocations() {
        if (relayListProc.running)
            return;

        locationsLoading = true;
        relayListText = "";
        relayListProc.exec(["mullvad", "relay", "list"]);
    }

    function refreshAccount() {
        if (!accountProc.running)
            accountProc.exec(["mullvad", "account", "get"]);
    }

    function refreshVersion() {
        if (!versionProc.running)
            versionProc.exec(["mullvad", "version"]);
    }

    function runCommand(command, name, followUp) {
        if (commandProc.running)
            return;

        lastCommandName = name;
        lastCommandError = "";
        errorMessage = "";
        pendingFollowUp = followUp || [];
        commandProc.exec(command);
    }

    function connect() {
        state = "connecting";
        runCommand(["mullvad", "connect"], "connect", []);
    }

    function disconnect() {
        state = "disconnecting";
        runCommand(["mullvad", "disconnect"], "disconnect", []);
    }

    function reconnect() {
        state = "connecting";
        runCommand(["mullvad", "reconnect"], "reconnect", []);
    }

    function toggleConnection() {
        if (connected || connecting)
            disconnect();
        else
            connect();
    }

    function setLocation(choice) {
        if (!choice)
            return;

        const command = ["mullvad", "relay", "set", "location"];
        if (choice.kind === "any") {
            command.push("any");
        } else if (choice.kind === "country") {
            command.push(choice.countryCode);
        } else if (choice.kind === "city") {
            command.push(choice.countryCode);
            command.push(choice.cityCode);
        } else if (choice.kind === "host") {
            command.push(choice.hostname);
        } else {
            return;
        }

        relayConstraintLabel = choice.label;
        const followUp = (connected || connecting) ? ["mullvad", "reconnect"] : [];
        runCommand(command, "set location", followUp);
    }

    function setAutoConnect(value) {
        autoConnect = !!value;
        runCommand(["mullvad", "auto-connect", "set", autoConnect ? "on" : "off"], "set auto-connect", []);
    }

    function setLanAllowed(value) {
        lanAllowed = !!value;
        runCommand(["mullvad", "lan", "set", lanAllowed ? "allow" : "block"], "set LAN sharing", []);
    }

    function setLockdownMode(value) {
        lockdownMode = !!value;
        runCommand(["mullvad", "lockdown-mode", "set", lockdownMode ? "on" : "off"], "set lockdown", []);
    }

    function setIpv6(value) {
        ipv6 = !!value;
        runCommand(["mullvad", "tunnel", "set", "ipv6", ipv6 ? "on" : "off"], "set IPv6", []);
    }

    function setQuantumResistant(value) {
        quantumResistant = !!value;
        runCommand(["mullvad", "tunnel", "set", "quantum-resistant", quantumResistant ? "on" : "off"], "set quantum resistance", []);
    }

    function setDaita(value) {
        daita = !!value;
        runCommand(["mullvad", "tunnel", "set", "daita", daita ? "on" : "off"], "set DAITA", []);
    }

    function locationChoices(query) {
        const q = (query || "").trim().toLowerCase();
        const result = [];
        const maxItems = q.length > 0 ? 80 : 64;

        for (let i = 0; i < locations.length; i++) {
            const choice = locations[i];
            if (q.length === 0 && (choice.kind === "city" || choice.kind === "host"))
                continue;

            const haystack = ((choice.label || "") + " " + (choice.sublabel || "") + " " + (choice.countryCode || "") + " " + (choice.cityCode || "")).toLowerCase();
            if (q.length > 0 && haystack.indexOf(q) === -1)
                continue;

            result.push(choice);
            if (result.length >= maxItems)
                break;
        }

        return result;
    }

    function applyStatus(status) {
        daemonAvailable = true;
        errorMessage = "";

        state = normalizeState(status.state || "unknown");
        const details = status.details || {};
        lockedDown = details.locked_down === true;

        const location = details.location || details.endpoint && details.endpoint.location || details.relay || {};
        applyLocation(location);
        lastUpdated = Qt.formatTime(new Date(), "hh:mm");
    }

    function applyLocation(location) {
        countryCode = "";
        cityCode = "";
        locationName = "";

        country = stringValue(location.country);
        city = stringValue(location.city);
        hostname = stringValue(location.hostname || location.exit_hostname);
        entryHostname = stringValue(location.entry_hostname);
        visibleIp = stringValue(location.ipv4 || location.ipv6 || location.exit_ip || location.ip);

        if (hostname.length > 0) {
            const parts = hostname.split("-");
            if (parts.length >= 2) {
                countryCode = parts[0];
                cityCode = parts[1];
            }
        }

        if (country.length > 0 && countryCode.length === 0)
            countryCode = codeForCountry(country);
        if (city.length > 0 && cityCode.length === 0)
            cityCode = codeForCity(countryCode, city);

        if (city.length > 0 && country.length > 0)
            locationName = city + ", " + country;
        else if (country.length > 0)
            locationName = country;
        else if (hostname.length > 0)
            locationName = hostname;
    }

    function parseStatusJson(text) {
        const trimmed = text.trim();
        if (trimmed.length === 0)
            return;

        try {
            applyStatus(JSON.parse(trimmed));
        } catch (e) {
            parseStatusText(trimmed);
        }
    }

    function parseStatusText(text) {
        const trimmed = text.trim();
        if (trimmed.length === 0)
            return;

        daemonAvailable = true;
        lastUpdated = Qt.formatTime(new Date(), "hh:mm");

        const lower = trimmed.toLowerCase();
        if (lower.indexOf("connected") === 0)
            state = "connected";
        else if (lower.indexOf("connecting") === 0)
            state = "connecting";
        else if (lower.indexOf("disconnecting") === 0)
            state = "disconnecting";
        else if (lower.indexOf("disconnected") === 0)
            state = "disconnected";
        else if (lower.indexOf("blocked") === 0 || lower.indexOf("error") === 0)
            state = "error";

        const visibleMatch = trimmed.match(/Visible location:\s*([^,]+),\s*([^\.]+)\.\s*(?:IPv4|IPv6):\s*([^\s]+)/);
        if (visibleMatch) {
            country = visibleMatch[1].trim();
            city = visibleMatch[2].trim();
            visibleIp = visibleMatch[3].trim();
            countryCode = codeForCountry(country);
            cityCode = codeForCity(countryCode, city);
            locationName = city + ", " + country;
        }

        if (lower.indexOf("locked") !== -1)
            lockedDown = true;
    }

    function parseRelayGet(text) {
        const locationMatch = text.match(/Location:\s*(.+)/);
        relayConstraint = locationMatch ? locationMatch[1].trim() : "";
        relayConstraintLabel = relayLabel(relayConstraint);
    }

    function parseRelayList(text) {
        const nextCountries = [];
        const nextLocations = [{ kind: "any", label: "Any location", sublabel: "Automatic relay selection", countryCode: "", cityCode: "" }];
        const nextCountryNames = {};
        const nextCityNames = {};
        let currentCountry = null;
        let currentCity = null;

        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            const countryMatch = line.match(/^([^\t].*?)\s+\(([a-z0-9]{2})\)$/);
            if (countryMatch) {
                currentCountry = {
                    kind: "country",
                    name: countryMatch[1].trim(),
                    code: countryMatch[2],
                    cities: []
                };
                nextCountries.push(currentCountry);
                nextCountryNames[currentCountry.code] = currentCountry.name;
                nextLocations.push({
                    kind: "country",
                    label: currentCountry.name,
                    sublabel: currentCountry.code.toUpperCase(),
                    countryCode: currentCountry.code,
                    cityCode: "",
                    hostname: ""
                });
                currentCity = null;
                continue;
            }

            const cityMatch = line.match(/^\t([^\t].*?)\s+\(([a-z0-9]{3})\)\s+@/);
            if (cityMatch && currentCountry) {
                const cityObj = {
                    kind: "city",
                    name: cityMatch[1].trim(),
                    code: cityMatch[2],
                    countryName: currentCountry.name,
                    countryCode: currentCountry.code
                };
                currentCity = cityObj;
                currentCountry.cities.push(cityObj);
                nextCityNames[currentCountry.code + ":" + cityObj.code] = cityObj.name;
                nextLocations.push({
                    kind: "city",
                    label: cityObj.name + ", " + currentCountry.name,
                    sublabel: currentCountry.code.toUpperCase() + " / " + cityObj.code.toUpperCase(),
                    countryCode: currentCountry.code,
                    cityCode: cityObj.code,
                    hostname: ""
                });
                continue;
            }

            const hostMatch = line.match(/^\t\t([a-z0-9-]+)\s+\(/);
            if (hostMatch && currentCountry && currentCity) {
                const relayHostname = hostMatch[1];
                nextLocations.push({
                    kind: "host",
                    label: relayHostname,
                    sublabel: currentCity.name + ", " + currentCountry.name,
                    countryCode: currentCountry.code,
                    cityCode: currentCity.code,
                    hostname: relayHostname
                });
            }
        }

        countries = nextCountries;
        locations = nextLocations;
        countryNamesByCode = nextCountryNames;
        cityNamesByKey = nextCityNames;
        if (country.length > 0 && countryCode.length === 0)
            countryCode = codeForCountry(country);
        if (city.length > 0 && cityCode.length === 0)
            cityCode = codeForCity(countryCode, city);
        relayConstraintLabel = relayLabel(relayConstraint);
        locationsLoading = false;
    }

    function parseAutoConnect(text) {
        autoConnect = text.toLowerCase().indexOf("on") !== -1;
    }

    function parseLan(text) {
        lanAllowed = text.toLowerCase().indexOf("allow") !== -1;
    }

    function parseLockdown(text) {
        lockdownMode = text.toLowerCase().indexOf("on") !== -1;
    }

    function parseTunnel(text) {
        const qr = text.match(/Quantum resistance:\s*(.+)/);
        const daitaMatch = text.match(/DAITA:\s*(.+)/);
        const ipv6Match = text.match(/IPv6:\s*(.+)/);

        if (qr)
            quantumResistant = qr[1].trim().toLowerCase() === "on";
        if (daitaMatch)
            daita = daitaMatch[1].trim().toLowerCase() === "true" || daitaMatch[1].trim().toLowerCase() === "on";
        if (ipv6Match)
            ipv6 = ipv6Match[1].trim().toLowerCase() === "on";
    }

    function parseAccount(text) {
        const accountMatch = text.match(/Mullvad account:\s*([0-9]+)/);
        const expiryMatch = text.match(/Expires at:\s*(.+)/);
        const deviceMatch = text.match(/Device name:\s*(.+)/);

        if (accountMatch)
            accountMasked = maskAccount(accountMatch[1].trim());
        if (expiryMatch)
            accountExpiry = expiryMatch[1].trim();
        if (deviceMatch)
            deviceName = deviceMatch[1].trim();
    }

    function parseVersion(text) {
        const versionMatch = text.match(/Current version\s*:\s*(.+)/);
        const supportedMatch = text.match(/Is supported\s*:\s*(.+)/);

        if (versionMatch)
            version = versionMatch[1].trim();
        if (supportedMatch)
            supported = supportedMatch[1].trim().toLowerCase() === "true";
    }

    function normalizeState(value) {
        const lower = (value || "").toLowerCase();
        if (lower.indexOf("disconnecting") !== -1)
            return "disconnecting";
        if (lower.indexOf("disconnected") !== -1)
            return "disconnected";
        if (lower.indexOf("connecting") !== -1)
            return "connecting";
        if (lower.indexOf("connected") !== -1)
            return "connected";
        if (lower.indexOf("error") !== -1)
            return "error";
        return lower.length > 0 ? lower : "unknown";
    }

    function relayLabel(raw) {
        if (!raw || raw === "any")
            return "Any location";

        const cityMatch = raw.match(/city\s+([a-z0-9]{3}),\s*([a-z0-9]{2})/);
        if (cityMatch) {
            const cityName = cityNamesByKey[cityMatch[2] + ":" + cityMatch[1]] || cityMatch[1].toUpperCase();
            const countryName = countryNamesByCode[cityMatch[2]] || cityMatch[2].toUpperCase();
            return cityName + ", " + countryName;
        }

        const countryMatch = raw.match(/country\s+([a-z0-9]{2})/);
        if (countryMatch)
            return countryNamesByCode[countryMatch[1]] || countryMatch[1].toUpperCase();

        const hostnameMatch = raw.match(/hostname\s+([a-z0-9-]+)/);
        if (hostnameMatch)
            return hostnameMatch[1];

        return raw;
    }

    function codeForCountry(name) {
        const needle = (name || "").toLowerCase();
        for (const code in countryNamesByCode) {
            if (countryNamesByCode[code].toLowerCase() === needle)
                return code;
        }
        return "";
    }

    function codeForCity(country, name) {
        const needle = (name || "").toLowerCase();
        for (const key in cityNamesByKey) {
            if (country.length > 0 && key.indexOf(country + ":") !== 0)
                continue;
            if (cityNamesByKey[key].toLowerCase() === needle)
                return key.split(":")[1];
        }
        return "";
    }

    function stringValue(value) {
        if (value === null || value === undefined)
            return "";
        return String(value);
    }

    function maskAccount(account) {
        if (account.length <= 8)
            return account;
        return account.slice(0, 4) + "..." + account.slice(account.length - 4);
    }

    property Timer statusTimer: Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: root.refreshStatus()
    }

    property Timer settingsTimer: Timer {
        interval: 300000
        repeat: true
        running: true
        onTriggered: root.refreshSettings()
    }

    property Timer refreshAfterCommandTimer: Timer {
        interval: 900
        repeat: false
        onTriggered: root.refreshAll()
    }

    property Timer listenRestartTimer: Timer {
        interval: 3000
        repeat: false
        onTriggered: {
            if (!root.statusListenProc.running)
                root.statusListenProc.running = true;
        }
    }

    property Process statusListenProc: Process {
        command: ["mullvad", "status", "listen"]
        stdout: SplitParser {
            onRead: data => {
                root.parseStatusText(data);
                root.refreshAfterCommandTimer.restart();
            }
        }
        stderr: SplitParser {
            onRead: data => {
                const text = data.trim();
                if (text.length > 0) {
                    root.daemonAvailable = false;
                    root.errorMessage = text;
                }
            }
        }
        onExited: { // qmllint disable signal-handler-parameters
            if (!root.listenRestartTimer.running)
                root.listenRestartTimer.restart();
        }
    }

    property Process statusProc: Process {
        stdout: StdioCollector {
            onStreamFinished: root.parseStatusJson(text)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim();
                if (text.length > 0) {
                    root.daemonAvailable = false;
                    root.errorMessage = text.split("\n")[0];
                }
            }
        }
    }

    property Process relayGetProc: Process {
        stdout: StdioCollector {
            onStreamFinished: root.parseRelayGet(text)
        }
    }

    property string relayListText: ""
    property Process relayListProc: Process {
        stdout: SplitParser {
            onRead: data => root.relayListText += data + "\n"
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0)
                    root.errorMessage = text.trim().split("\n")[0];
            }
        }
        onExited: root.parseRelayList(root.relayListText) // qmllint disable signal-handler-parameters
    }

    property Process autoProc: Process {
        stdout: StdioCollector {
            onStreamFinished: root.parseAutoConnect(text)
        }
    }

    property Process lanProc: Process {
        stdout: StdioCollector {
            onStreamFinished: root.parseLan(text)
        }
    }

    property Process lockdownProc: Process {
        stdout: StdioCollector {
            onStreamFinished: root.parseLockdown(text)
        }
    }

    property Process tunnelProc: Process {
        stdout: StdioCollector {
            onStreamFinished: root.parseTunnel(text)
        }
    }

    property Process accountProc: Process {
        stdout: StdioCollector {
            onStreamFinished: root.parseAccount(text)
        }
    }

    property Process versionProc: Process {
        stdout: StdioCollector {
            onStreamFinished: root.parseVersion(text)
        }
    }

    property Process commandProc: Process {
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: root.lastCommandError = text.trim()
        }
        onExited: exitCode => { // qmllint disable signal-handler-parameters
            if (exitCode === 0 && root.pendingFollowUp.length > 0) {
                const followUp = root.pendingFollowUp;
                root.pendingFollowUp = [];
                root.runCommand(followUp, "reconnect", []);
                return;
            }

            if (exitCode !== 0) {
                root.errorMessage = root.lastCommandError.length > 0 ? root.lastCommandError.split("\n")[0] : "Command failed: " + root.lastCommandName;
            }

            root.pendingFollowUp = [];
            root.refreshAfterCommandTimer.restart();
        }
    }
}
