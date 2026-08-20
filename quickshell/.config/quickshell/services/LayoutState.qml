pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import Quickshell.Io

QtObject {
    id: root

    readonly property var layouts: ["dwindle", "master", "scrolling"]
    property string currentLayout: "dwindle"

    function refresh() {
        if (!queryProc.running)
            queryProc.running = true;
    }

    function toggle() {
        const currentIndex = layouts.indexOf(currentLayout);
        const nextLayout = layouts[(currentIndex + 1) % layouts.length];
        currentLayout = nextLayout;
        layoutProc.command = Hyprland.usingLua
            ? ["hyprctl", "eval", "hl.config({ general = { layout = \"" + nextLayout + "\" } })"]
            : ["hyprctl", "keyword", "general:layout", nextLayout];
        layoutProc.running = true;
    }

    property Process queryProc: Process {
        command: ["hyprctl", "-j", "getoption", "general:layout"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text);
                    const value = result.str || result.value || "";
                    if (value)
                        root.currentLayout = String(value);
                } catch (error) {
                    const match = text.match(/(?:str|value):\s*([^\s]+)/);
                    if (match)
                        root.currentLayout = match[1];
                }
            }
        }
    }

    property Process layoutProc: Process {
        onExited: root.refreshTimer.restart() // qmllint disable signal-handler-parameters
    }

    property Timer refreshTimer: Timer {
        interval: 250
        repeat: false
        onTriggered: root.refresh()
    }

    property Timer pollTimer: Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
