pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import Quickshell.Networking

QtObject {
    id: root

    // Aggregated view over the Quickshell Networking service. Connection
    // actions use the pure-QML API where it is solid (scan, connect, wifi
    // toggle); device disconnect falls back to nmcli because this revision
    // exposes no disconnect method on the device object.

    property var _devices: Networking.devices.values

    readonly property var wifiDevice: {
        const devices = root._devices;
        for (let i = 0; i < devices.length; i++) {
            if (devices[i] && devices[i].type === DeviceType.Wifi)
                return devices[i];
        }
        return null;
    }

    readonly property var wiredDevice: {
        const devices = root._devices;
        for (let i = 0; i < devices.length; i++) {
            if (devices[i] && devices[i].type === DeviceType.Wired)
                return devices[i];
        }
        return null;
    }

    readonly property bool wifiConnected: wifiDevice ? wifiDevice.connected : false
    readonly property bool wiredConnected: wiredDevice ? wiredDevice.connected : false
    readonly property bool connected: wifiConnected || wiredConnected
    readonly property string activeWifiName: wifiConnected && wifiDevice.networks && wifiDevice.networks.values
        ? (connectedNetworkName(wifiDevice) || "")
        : ""
    readonly property var activeDevice: wiredConnected ? wiredDevice : (wifiConnected ? wifiDevice : null)
    readonly property string address: activeDevice ? (activeDevice.address || "") : ""

    readonly property string indicatorLabel: {
        if (wiredConnected)
            return "ETH";
        if (wifiConnected)
            return activeWifiName.length > 10 ? activeWifiName.substring(0, 10).toUpperCase() : activeWifiName.toUpperCase();
        if (!wifiDevice && !wiredDevice)
            return "OFF";
        if (wifiEnabled)
            return "WIFI";
        return "DOWN";
    }

    readonly property string iconKey: {
        if (wiredConnected)
            return "network-wired";
        if (wifiConnected) {
            const strength = activeWifiStrength;
            if (strength >= 80) return "network-wireless-signal-excellent";
            if (strength >= 60) return "network-wireless-signal-good";
            if (strength >= 40) return "network-wireless-signal-ok";
            if (strength > 0) return "network-wireless-signal-weak";
            return "network-wireless";
        }
        return "network-wireless-disconnected";
    }

    readonly property int activeWifiStrength: {
        if (!wifiConnected || !wifiDevice || !wifiDevice.networks || !wifiDevice.networks.values)
            return 0;
        let best = 0;
        const networks = wifiDevice.networks.values;
        for (let i = 0; i < networks.length; i++) {
            const network = networks[i];
            if (network && network.connected && network.signalStrength > best)
                best = network.signalStrength;
        }
        return Math.round(best);
    }

    readonly property bool wifiEnabled: Networking.wifiEnabled

    // Details-consumer gating for the wifi scanner, mirroring Stats/Waydroid.
    property int detailsConsumers: 0
    property string errorMessage: ""
    readonly property bool disconnecting: disconnectProc.running

    property Binding scannerBinding: Binding {
        target: root.wifiDevice
        property: "scannerEnabled"
        value: root.detailsConsumers > 0
        when: root.wifiDevice !== null
        restoreMode: Binding.RestoreBindingOrValue
    }

    function beginDetails() {
        detailsConsumers++;
    }

    function endDetails() {
        detailsConsumers = Math.max(0, detailsConsumers - 1);
    }

    function setWifiEnabled(enabled) {
        Networking.wifiEnabled = !!enabled;
    }

    function networkIsOpen(network) {
        return network && (network.security === WifiSecurityType.Open || network.security === WifiSecurityType.Owe);
    }

    function connectToNetwork(network, psk) {
        if (!network)
            return false;
        errorMessage = "";
        try {
            network.connectWithPsk(String(psk || ""));
            return true;
        } catch (error) {
            errorMessage = "Could not request a connection. Check the network and credentials.";
            return false;
        }
    }

    function disconnectDevice(device) {
        if (!device || disconnecting)
            return;
        errorMessage = "";
        disconnectProc.exec(["nmcli", "device", "disconnect", String(device.name || "")]);
    }

    property Process disconnectProc: Process {
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: exitCode => { // qmllint disable signal-handler-parameters
            if (exitCode !== 0)
                root.errorMessage = "Disconnect failed. Check NetworkManager permissions and device state.";
        }
        onStarted: root.errorMessage = ""
    }

    function connectedNetworkName(device) {
        if (!device || !device.networks || !device.networks.values)
            return "";
        const networks = device.networks.values;
        for (let i = 0; i < networks.length; i++) {
            if (networks[i] && networks[i].connected)
                return networks[i].name || "";
        }
        return "";
    }

    function sortedWifiNetworks() {
        if (!wifiDevice || !wifiDevice.networks || !wifiDevice.networks.values)
            return [];
        const list = Array.from(wifiDevice.networks.values);
        list.sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            return (b.signalStrength || 0) - (a.signalStrength || 0);
        });
        return list;
    }

    function statusJson() {
        return JSON.stringify({
            connected: connected,
            wifi: activeWifiName,
            strength: activeWifiStrength,
            wired: wiredConnected,
            address: address,
            wifiEnabled: wifiEnabled,
            backend: String(Networking.backend)
        });
    }

    property Connections devicesConnections: Connections {
        target: Networking.devices
        function onValuesChanged() {
            root._devices = Networking.devices.values;
        }
    }

    Component.onCompleted: {
        root._devices = Networking.devices.values;
    }
}
