import QtQuick
import Quickshell
import Quickshell.Io

// Compatibility entrypoint. The real power picker is owned by shell.qml.
ShellRoot {
    id: root
    readonly property string qsBin: Quickshell.env("QUICKSHELL_BIN") || "quickshell"
    property bool finished: false

    Process {
        id: openProcess
        command: [root.qsBin, "ipc", "call", "shell", "openPicker", "power", "{}"]
        onExited: exitCode => { // qmllint disable signal-handler-parameters
            if (exitCode !== 0)
                console.error("openPicker ipc failed with exit code " + exitCode);
            root.finished = true;
            Qt.quit();
        } // qmllint enable signal-handler-parameters
    }

    // On FailedToStart Quickshell emits runningChanged but never exited; this
    // watchdog prevents an immortal windowless instance.
    Timer {
        interval: 15000
        running: true
        repeat: false
        onTriggered: {
            if (!root.finished) {
                console.error("picker ipc did not complete (spawn failure or timeout)");
                Qt.quit();
            }
        }
    }

    Component.onCompleted: openProcess.running = true
}
