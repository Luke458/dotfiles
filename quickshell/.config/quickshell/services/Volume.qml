pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

QtObject {
    id: root

    // --- Core Properties ---
    property PwNode audioSink: Pipewire.defaultAudioSink
    
    // Direct QML bindings for reliable reactivity
    readonly property real volume: (audioSink && audioSink.audio) ? audioSink.audio.volume : 0
    readonly property bool muted: (audioSink && audioSink.audio) ? audioSink.audio.muted : false
    readonly property int volumePercent: Math.round(volume * 100)

    // --- Filtered Lists ---
    readonly property var sinks: Pipewire.nodes.values.filter(node => 
        node.isSink && !node.isStream && node.audio && node.ready
    )
    
    readonly property var apps: {
        const rawApps = Pipewire.nodes.values.filter((node) => {
            // Revert 'ready' check for visibility - some streams (Helium) might report ready: false
            if (!node.isStream || !node.audio) return false;
            
            const props = node.properties || {};
            const name = (node.name || "").toLowerCase();
            const appName = (props["application.name"] || "").toLowerCase();
            
            if (name.includes("cava") || appName.includes("cava")) return false;
            if (name.includes("easyeffects") || appName.includes("easyeffects")) return false; 
            
            return true;
        });

        // Deduplicate and prioritize active streams
        rawApps.sort((a, b) => {
            const aProps = a.properties || {};
            const bProps = b.properties || {};
            const aCorked = aProps["pulse.corked"] === "true" || aProps["pulse.corked"] === true;
            const bCorked = bProps["pulse.corked"] === "true" || bProps["pulse.corked"] === true;
            if (aCorked !== bCorked) return aCorked ? 1 : -1;
            return b.id - a.id;
        });

        const unique = [];
        const seen = new Set();
        for (const app of rawApps) {
            const name = getAppName(app).toLowerCase();
            if (!seen.has(name)) {
                unique.push(app);
                seen.add(name);
            }
        }
        return unique;
    }

    // --- Control Functions ---
    function toggleMute() { 
        if (audioSink && audioSink.audio && audioSink.ready) 
            audioSink.audio.muted = !audioSink.audio.muted; 
    }

    function setVolume(val) { 
        if (audioSink && audioSink.audio && audioSink.ready) { 
            audioSink.audio.muted = false; 
            audioSink.audio.volume = Math.max(0, Math.min(1, val)); 
        } 
    }

    function changeVolume(delta) { 
        setVolume(root.volume + delta); 
    }

    // Controls ALL streams belonging to the same application
    function setAppVolume(appName, val) {
        const name = appName.toLowerCase();
        Pipewire.nodes.values.forEach(node => {
            if (node.isStream && node.audio) { // No ready check here to ensure we find the stream
                if (getAppName(node).toLowerCase() === name) {
                    // But check ready before writing to avoid unbound error
                    if (node.ready) {
                        node.audio.volume = Math.max(0, Math.min(1, val));
                    }
                }
            }
        });
    }

    function toggleAppMute(appName) {
        const name = appName.toLowerCase();
        Pipewire.nodes.values.forEach(node => {
            if (node.isStream && node.audio) {
                if (getAppName(node).toLowerCase() === name) {
                    if (node.ready) {
                        node.audio.muted = !node.audio.muted;
                    }
                }
            }
        });
    }

    function selectSink(node) { 
        if (node && node.ready) Pipewire.preferredDefaultAudioSink = node; 
    }

    // --- Helper Functions ---
    function getNodeName(node) {
        if (!node) return "Unknown";
        return node.nickname || node.description || node.name || "Unknown";
    }

    function getAppName(node) {
        if (!node) return "Unknown";
        const props = node.properties || {};
        
        const appName = props["application.name"] || "";
        const mediaName = props["media.name"] || "";
        const binary = props["application.process.binary"] || "";
        
        const genericNames = ["chromium", "web content", "playback", "firefox", "chromium input", "pulseaudio", "alsa-sink", "alsa-source"];
        const isGeneric = !appName || genericNames.includes(appName.toLowerCase());

        if (isGeneric && binary) {
            const bName = binary.split('/').pop();
            if (bName && !genericNames.includes(bName.toLowerCase())) {
                return bName.charAt(0).toUpperCase() + bName.slice(1);
            }
        }

        return appName || mediaName || getNodeName(node);
    }

    function getAppIcon(node) {
        if (!node) return "audio-card";
        
        const appName = getAppName(node).toLowerCase();
        if (appName === "helium") {
            return "file://" + Quickshell.shellPath("assets/helium.svg");
        }

        const props = node.properties || {};
        const icon = props["application.icon-name"] || props["icon-name"] || "";
        const binary = props["application.process.binary"] || "";
        
        if ((!icon || icon === "audio-card") && binary) {
            return binary.split('/').pop().toLowerCase();
        }
        
        return icon || "audio-card";
    }

    // --- Subscriptions ---
    property PwObjectTracker _tracker: PwObjectTracker {
        objects: [root.audioSink, Pipewire.nodes]
    }
}
