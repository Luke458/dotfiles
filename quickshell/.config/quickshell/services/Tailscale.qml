pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Tailscale status/control service. Mirrors services/SingBox.qml: poll the CLI
// for status, run mutations through one action process, and expose a small
// derived surface for the indicator and details flyout.
QtObject {
    id: root

    property bool installed: true
    property bool loading: true
    property bool busy: false

    // Optimistic on/off so the bar reacts the instant you toggle, instead of
    // waiting for the next status poll. -1 follows reality, 0/1 is pending.
    property int _desired: -1

    property string backendState: "Unknown"
    property bool needsLogin: false
    property string authUrl: ""
    property string selfName: ""
    property string selfDnsName: ""
    property string selfIp: ""
    property string selfUserId: ""
    property bool fileSharing: false
    property var peers: []
    property var exitNodes: []
    property string errorMessage: ""
    property string lastMessage: ""
    property int detailsConsumers: 0
    property bool refreshQueued: false
    property string actionName: ""

    readonly property bool running: backendState === "Running"
    readonly property bool stopped: backendState === "Stopped"
    readonly property bool active: _desired === -1 ? running : _desired === 1
    readonly property int onlinePeerCount: {
        let count = 0;
        for (let i = 0; i < peers.length; i++) {
            if (peers[i].Online)
                count++;
        }
        return count;
    }
    readonly property string statusText: {
        if (!installed)
            return "Not installed";
        if (errorMessage.length > 0 && !running)
            return "Unavailable";
        if (needsLogin)
            return "Needs login";
        if (running)
            return "Connected";
        if (stopped)
            return "Disconnected";
        return backendState;
    }

    Component.onCompleted: checkInstalled()

    function beginDetails() {
        detailsConsumers += 1;
        refresh();
    }

    function endDetails() {
        detailsConsumers = Math.max(0, detailsConsumers - 1);
    }

    // ── Parsing helpers ──────────────────────────────────────────────────────

    function filterIPv4(ips) {
        const result = [];
        if (!ips || typeof ips.length !== "number")
            return result;
        for (let i = 0; i < ips.length; i++) {
            const ip = String(ips[i] || "");
            if (/^100\./.test(ip))
                result.push(ip);
        }
        return result;
    }

    function filterIPv6(ips) {
        const result = [];
        if (!ips || typeof ips.length !== "number")
            return result;
        for (let i = 0; i < ips.length; i++) {
            const ip = String(ips[i] || "");
            if (/^fd7a:115c:a1e0:/i.test(ip))
                result.push(ip);
        }
        return result;
    }

    function cleanDnsName(name) {
        const value = String(name || "");
        return value.length > 0 && value.charAt(value.length - 1) === "." ? value.slice(0, -1) : value;
    }

    function shortDnsName(name) {
        const clean = cleanDnsName(name);
        return clean === "" ? "" : String(clean.split(".")[0] || clean);
    }

    function displayHostName(hostName, dnsName) {
        const host = String(hostName || "");
        if (host !== "" && host.toLowerCase() !== "localhost")
            return host;
        return shortDnsName(dnsName) || host || "Unknown";
    }

    function isMullvadHost(name) {
        const value = String(name || "").toLowerCase();
        const suffix = ".mullvad.ts.net";
        return value.length > suffix.length && value.indexOf(suffix) === value.length - suffix.length;
    }

    function osIcon(os) {
        const value = String(os || "").toLowerCase();
        if (value === "linux")
            return "\u{f0317}";
        if (value === "macos" || value === "ios")
            return "\u{f0304}";
        if (value === "windows")
            return "\u{f0379}";
        if (value === "android")
            return "\u{f0032}";
        return "\u{f0373}";
    }

    function hasFileSharing(self) {
        const capability = "https://tailscale.com/cap/file-sharing";
        const capMap = self && self.CapMap ? self.CapMap : null;
        if (capMap && capMap[capability] !== undefined)
            return true;
        const capabilities = (self && self.Capabilities) || [];
        for (let i = 0; i < capabilities.length; i++) {
            if (String(capabilities[i]) === capability)
                return true;
        }
        return false;
    }

    function normalizePeer(id, peer) {
        const source = peer || {};
        const ips = Array.isArray(source.TailscaleIPs) ? source.TailscaleIPs : [];
        const dns = cleanDnsName(source.DNSName);
        return {
            id: String(id || ""),
            HostName: displayHostName(source.HostName, dns),
            DisplayName: displayHostName(source.HostName, dns),
            DNSName: dns,
            ShortName: shortDnsName(source.DNSName),
            TailscaleIPs: filterIPv4(ips),
            TailscaleIPv6: filterIPv6(ips),
            Online: source.Online === true,
            OS: String(source.OS || ""),
            UserID: String(source.UserID || ""),
            Tags: Array.isArray(source.Tags) ? source.Tags : [],
            ExitNode: source.ExitNode === true,
            ExitNodeOption: source.ExitNodeOption === true,
            Mullvad: isMullvadHost(source.DNSName) || isMullvadHost(source.HostName)
        };
    }

    function applyStatus(text) {
        let data;
        try {
            data = JSON.parse(String(text || ""));
        } catch (error) {
            errorMessage = "Failed to parse tailscale status";
            return;
        }

        backendState = String(data.BackendState || "Unknown");
        needsLogin = backendState === "NeedsLogin";
        authUrl = String(data.AuthURL || "");

        const self = data.Self || {};
        selfName = displayHostName(self.HostName, self.DNSName);
        selfDnsName = cleanDnsName(self.DNSName);
        const selfIps = filterIPv4(self.TailscaleIPs || data.TailscaleIPs || []);
        selfIp = selfIps.length > 0 ? String(selfIps[0]) : "";
        selfUserId = String(self.UserID || "");
        fileSharing = hasFileSharing(self);

        if (_desired !== -1 && running === (_desired === 1))
            _desired = -1;

        const all = [];
        const rawPeers = data.Peer || {};
        for (const id in rawPeers) {
            if (!Object.prototype.hasOwnProperty.call(rawPeers, id))
                continue;
            const normalized = normalizePeer(id, rawPeers[id]);
            if (normalized.Mullvad)
                continue;
            all.push(normalized);
        }
        all.sort((a, b) => {
            if (a.Online !== b.Online)
                return a.Online ? -1 : 1;
            return String(a.HostName).localeCompare(String(b.HostName));
        });

        peers = all;
        exitNodes = all.filter(peer => peer.ExitNodeOption === true);
        errorMessage = "";
    }

    function resetState() {
        backendState = "Stopped";
        needsLogin = false;
        authUrl = "";
        selfName = "";
        selfDnsName = "";
        selfIp = "";
        selfUserId = "";
        fileSharing = false;
        peers = [];
        exitNodes = [];
        if (_desired === 0)
            _desired = -1;
    }

    // ── Actions ──────────────────────────────────────────────────────────────

    function checkInstalled() {
        if (whichProc.running)
            return;
        whichProc.exec(["which", "tailscale"]);
    }

    function refresh() {
        if (!installed)
            return checkInstalled();
        if (busy || statusProc.running) {
            refreshQueued = true;
            return;
        }
        loading = true;
        statusProc.exec(["tailscale", "status", "--json"]);
    }

    function runAction(argumentsList, name) {
        if (busy || actionProc.running)
            return;
        busy = true;
        actionName = name || "";
        errorMessage = "";
        lastMessage = "";
        actionProc.exec(argumentsList);
    }

    function toggle() {
        if (!installed)
            return;
        if (active)
            down();
        else
            up();
    }

    function down() {
        _desired = 0;
        runAction(["tailscale", "down"], "Disconnecting");
    }

    function up() {
        _desired = 1;
        runAction(["tailscale", "up"], "Connecting");
    }

    function exitNodeTarget(peer) {
        if (!peer)
            return "";
        if (peer.TailscaleIPs && peer.TailscaleIPs.length > 0)
            return String(peer.TailscaleIPs[0]);
        return peer.DNSName || peer.HostName || "";
    }

    function setExitNode(peer) {
        if (!installed || busy || !peer)
            return;
        const isActive = peer.ExitNode === true;
        const target = isActive ? "" : exitNodeTarget(peer);
        if (!isActive && target === "")
            return;
        runAction(["tailscale", "set", "--exit-node=" + target], isActive ? "Clearing exit node" : "Setting exit node");
    }

    function copyToClipboard(value, label) {
        const text = String(value || "");
        if (text.length === 0)
            return;
        Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" | wl-copy", "tailscale-copy", text]);
        lastMessage = (label ? label + " " : "") + "copied";
        root.messageTimer.restart();
    }

    function copyPeerIp(peer) {
        if (!peer || !peer.TailscaleIPs || peer.TailscaleIPs.length === 0)
            return;
        copyToClipboard(peer.TailscaleIPs[0], peer.HostName + " IP");
    }

    function copyPeerDns(peer) {
        if (!peer || peer.DNSName === "")
            return;
        copyToClipboard(peer.DNSName, peer.HostName + " DNS");
    }

    function peerAddress(peer) {
        if (!peer)
            return "";
        if (peer.TailscaleIPs && peer.TailscaleIPs.length > 0)
            return String(peer.TailscaleIPs[0]);
        return peer.DNSName || "";
    }

    // ── Processes ────────────────────────────────────────────────────────────

    property Process whichProc: Process {
        stdout: StdioCollector {}
        stderr: StdioCollector {}

        onExited: exitCode => { // qmllint disable signal-handler-parameters
            root.installed = exitCode === 0;
            if (root.installed)
                root.refresh();
            else {
                root.loading = false;
                root.errorMessage = "tailscale CLI not found";
            }
        }
    }

    property Process statusProc: Process {
        stdout: StdioCollector { id: statusStdout }
        stderr: StdioCollector { id: statusStderr }

        onExited: exitCode => { // qmllint disable signal-handler-parameters
            root.loading = false;
            const output = String(statusStdout.text || "");
            if (exitCode === 0 && output.trim().length > 0)
                root.applyStatus(output);
            else if (exitCode === 0)
                root.resetState();
            else
                root.errorMessage = String(statusStderr.text || "").trim() || "tailscale status failed";

            if (root.refreshQueued && !root.busy) {
                root.refreshQueued = false;
                Qt.callLater(() => root.refresh());
            }
        }
    }

    property Process actionProc: Process {
        stdout: StdioCollector { id: actionStdout }
        stderr: StdioCollector { id: actionStderr }

        onExited: exitCode => { // qmllint disable signal-handler-parameters
            root.busy = false;
            const output = String(actionStdout.text || "");
            const error = String(actionStderr.text || "");
            if (exitCode === 0) {
                root.lastMessage = output.trim() || (root.actionName + " complete");
                if (root.actionName === "Connecting")
                    root.lastMessage = "Connected";
                root.messageTimer.restart();
            } else {
                root._desired = -1;
                root.errorMessage = error.trim() || output.trim() || (root.actionName + " failed");
            }
            root.actionName = "";
            root.refresh();
        }
    }

    property Timer messageTimer: Timer {
        interval: 3000
        repeat: false
        onTriggered: root.lastMessage = ""
    }

    property Timer refreshTimer: Timer {
        interval: root.detailsConsumers > 0 ? 10000 : 30000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
