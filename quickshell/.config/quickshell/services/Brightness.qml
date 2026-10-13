pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Display brightness over DDC/CI (external monitors) with an OSD. Internal
// panels are not present on this host; if /sys/class/backlight appears later,
// brightnessctl can be added as a primary path.
QtObject {
    id: root

    property bool available: false
    property var displays: ({}) // Hyprland monitor name -> ddcutil display number
    property var values: ({})   // ddcutil display number -> percent
    property string pendingMonitor: ""
    property int pendingDirection: 0
    property int lastPercent: -1
    readonly property int stepPercent: 5

    function currentMonitorName() {
        return Hyprland.focusedMonitor && Hyprland.focusedMonitor.name
            ? String(Hyprland.focusedMonitor.name) : "";
    }

    function currentDisplay() {
        const name = currentMonitorName();
        return displays[name] !== undefined ? Number(displays[name]) : null;
    }

    function refresh() {
        if (!detectProc.running)
            detectProc.running = true;
    }

    function step(direction) {
        if (!available) {
            Osd.showMessage("warning", "Brightness unavailable");
            return;
        }
        const display = currentDisplay();
        if (display === null) {
            Osd.showMessage("warning", "No brightness for this display");
            return;
        }
        if (values[display] === undefined) {
            pendingMonitor = currentMonitorName();
            pendingDirection = direction;
            getProc.command = ["ddcutil", "--display", String(display), "--terse", "getvcp", "10"];
            getProc.running = true;
            return;
        }
        applyStep(display, direction);
    }

    function applyStep(display, direction) {
        const base = Number(values[display] !== undefined ? values[display] : 50);
        const target = Math.max(0, Math.min(100, base + direction * stepPercent));
        root.values = Object.assign({}, root.values, { [display]: target });
        root.lastPercent = target;
        Osd.showProgress("brightness", target, 100);
        setProc.command = ["ddcutil", "--display", String(display), "--sleep-multiplier", "0.5", "setvcp", "10", String(target)];
        setProc.running = true;
    }

    function raise() { step(1); }
    function lower() { step(-1); }

    function setPercent(value) {
        if (!available) return;
        const display = currentDisplay();
        if (display === null) return;
        root.values = Object.assign({}, root.values, { [display]: Math.max(0, Math.min(100, Math.round(Number(value)))) });
        root.lastPercent = root.values[display];
        Osd.showProgress("brightness", root.lastPercent, 100);
        setProc.command = ["ddcutil", "--display", String(display), "--sleep-multiplier", "0.5", "setvcp", "10", String(root.lastPercent)];
        setProc.running = true;
    }

    function statusJson() {
        return JSON.stringify({
            available: available,
            monitor: currentMonitorName(),
            display: currentDisplay(),
            percent: lastPercent
        });
    }

    function parseDetect(output) {
        const lines = String(output || "").split("\n");
        let current = null;
        const map = ({});
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            let match = line.match(/^Display\s+(\d+)/);
            if (match) {
                current = Number(match[1]);
                continue;
            }
            match = line.match(/DRM_connector:\s*(\S+)/);
            if (match && current !== null) {
                const name = String(match[1]).replace(/^card\d+-/, "");
                map[name] = current;
            }
        }
        root.displays = map;
        root.available = Object.keys(map).length > 0;
    }

    function parseGet(text) {
        const match = String(text || "").match(/VCP\s+10\s+\S+\s+(\d+)\s+(\d+)/);
        const display = currentDisplay();
        if (match && display !== null) {
            const current = Number(match[1]);
            const max = Number(match[2]) || 100;
            const percent = Math.round(current * 100 / max);
            root.values = Object.assign({}, root.values, { [display]: percent });
            root.lastPercent = percent;
        }
        if (pendingDirection !== 0) {
            const direction = pendingDirection;
            pendingDirection = 0;
            if (display !== null) applyStep(display, direction);
        }
    }

    property Process detectProc: Process {
        command: ["ddcutil", "detect"]
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.parseDetect(text)
        }
    }

    property Process getProc: Process {
        running: false
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.parseGet(text)
        }
    }

    property Process setProc: Process {
        running: false
    }

    property Connections _hyprlandConnections: Connections {
        target: Hyprland
        function onFocusedMonitorChanged() { root.lastPercent = -1; }
    }
}
