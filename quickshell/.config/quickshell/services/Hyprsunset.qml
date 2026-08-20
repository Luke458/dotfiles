pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property bool enabled: false
    property int temperature: 3500
    property int gamma: 100 // 100%

    // --- Configuration Scheduling properties ---
    property string configContent: ""
    property var parsedProfiles: []
    property string lastActiveProfileTime: ""

    // --- IPC Processes ---
    property Process setTempProc: Process { 
        command: ["hyprctl", "hyprsunset", "temperature", root.temperature.toString()] 
    }
    
    property Process resetProc: Process {
        // `identity` does not reliably restore gamma on every hyprsunset
        // release, so reset both controls in a defined order.
        command: ["sh", "-c", "hyprctl hyprsunset identity; hyprctl hyprsunset gamma 100"]
    }
    
    property Process setGammaProc: Process {
        command: ["hyprctl", "hyprsunset", "gamma", root.gamma.toString()]
    }

    // Process to read configuration file
    property Process readConfigProc: Process {
        command: ["sh", "-c", "cat $HOME/.config/hypr/hyprsunset.conf"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                root.configContent += data + "\n";
            }
        }
        onExited: { // qmllint disable signal-handler-parameters
            root.parsedProfiles = root.parseConfig(root.configContent);
            root.checkSchedule(true);
        }
    }

    // Timer to periodically check the schedule (every 10 seconds)
    property Timer scheduleTimer: Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: root.checkSchedule(false)
    }

    function setEnabled(value) {
        const nextEnabled = !!value;
        if (enabled === nextEnabled) {
            if (enabled) {
                applyTemperature();
                applyGamma();
            } else {
                applyIdentity();
            }
            return;
        }

        enabled = nextEnabled;
        if (enabled) {
            applyTemperature();
            applyGamma();
        } else {
            applyIdentity();
        }
    }

    function toggle() {
        setEnabled(!enabled);
    }

    function setTemperature(value) {
        const nextTemperature = Math.round(value);
        if (temperature !== nextTemperature) {
            temperature = nextTemperature;
        } else if (enabled) {
            applyTemperature();
        }
    }

    function setGamma(value) {
        const nextGamma = Math.round(value);
        if (gamma !== nextGamma) {
            gamma = nextGamma;
        } else if (enabled) {
            applyGamma();
        }
    }

    function applyIdentity() {
        debounceTimer.stop();
        gammaDebounce.stop();
        setTempProc.running = false;
        setGammaProc.running = false;
        resetProc.running = false;
        resetProc.running = true;
    }

    function applyTemperature() {
        if (enabled) {
            setTempProc.running = false;
            setTempProc.running = true;
        }
    }

    function applyGamma() {
        if (enabled) {
            setGammaProc.running = false;
            setGammaProc.running = true;
        }
    }

    onTemperatureChanged: {
        if (enabled) {
            debounceTimer.restart();
        }
    }
    
    onGammaChanged: {
        gammaDebounce.restart();
    }

    property Timer debounceTimer: Timer {
        interval: 100
        onTriggered: root.applyTemperature()
    }
    
    property Timer gammaDebounce: Timer {
        interval: 100
        onTriggered: root.applyGamma()
    }

    Component.onCompleted: {
        readConfigProc.running = true;
    }

    // --- Scheduling Helper Functions ---
    function parseConfig(content) {
        let profiles = [];
        let currentProfile = null;
        let lines = content.split('\n');
        for (let i = 0; i < lines.length; i++) {
            let line = lines[i].trim();
            if (line === "" || line.startsWith("#")) {
                continue;
            }
            if (line.startsWith("profile") && line.endsWith("{")) {
                currentProfile = {};
                continue;
            }
            if (line === "}") {
                if (currentProfile) {
                    if (currentProfile.time) {
                        let timeParts = currentProfile.time.split(':');
                        let hours = parseInt(timeParts[0], 10);
                        let minutes = parseInt(timeParts[1], 10);
                        currentProfile.minutes = hours * 60 + minutes;
                        currentProfile.isIdentity = (currentProfile.identity === "true");
                        
                        if (currentProfile.temperature) {
                            currentProfile.tempVal = parseInt(currentProfile.temperature, 10);
                        } else {
                            currentProfile.tempVal = 6000; // default temperature
                        }
                        
                        if (currentProfile.gamma) {
                            currentProfile.gammaVal = Math.round(parseFloat(currentProfile.gamma) * 100);
                        } else {
                            currentProfile.gammaVal = 100;
                        }
                        
                        profiles.push(currentProfile);
                    }
                    currentProfile = null;
                }
                continue;
            }
            if (currentProfile && line.indexOf("=") !== -1) {
                let index = line.indexOf("=");
                let key = line.substring(0, index).trim();
                let val = line.substring(index + 1).trim();
                if (val.indexOf("#") !== -1) {
                    val = val.substring(0, val.indexOf("#")).trim();
                }
                currentProfile[key] = val;
            }
        }
        profiles.sort((a, b) => a.minutes - b.minutes);
        console.log("Hyprsunset: Loaded " + profiles.length + " profiles from config.");
        return profiles;
    }

    function findActiveProfile(profiles, currentMinutes) {
        if (!profiles || profiles.length === 0) return null;
        if (currentMinutes < profiles[0].minutes) {
            return profiles[profiles.length - 1];
        }
        for (let i = profiles.length - 1; i >= 0; i--) {
            if (profiles[i].minutes <= currentMinutes) {
                return profiles[i];
            }
        }
        return null;
    }

    function checkSchedule(init) {
        if (parsedProfiles.length === 0) return;
        
        let now = new Date();
        let currentMinutes = now.getHours() * 60 + now.getMinutes();
        let activeProfile = findActiveProfile(parsedProfiles, currentMinutes);
        if (!activeProfile) return;
        
        if (init || activeProfile.time !== lastActiveProfileTime) {
            lastActiveProfileTime = activeProfile.time;
            console.log("Hyprsunset: Switched to active profile from: " + activeProfile.time + 
                        " (enabled: " + !activeProfile.isIdentity + 
                        ", temp: " + activeProfile.tempVal + 
                        ", gamma: " + activeProfile.gammaVal + ")");
            
            if (activeProfile.isIdentity) {
                root.setEnabled(false);
            } else {
                root.setTemperature(activeProfile.tempVal);
                root.setGamma(activeProfile.gammaVal);
                root.setEnabled(true);
            }
        }
    }
}
