import QtQuick
import Quickshell
import Quickshell.Io

// Compatibility entrypoint. The real power picker is owned by shell.qml.
ShellRoot {
    Process {
        id: openProcess
        command: ["quickshell", "ipc", "call", "shell", "openPicker", "power", "{}"]
        onExited: Qt.quit() // qmllint disable signal-handler-parameters
    }

    Component.onCompleted: openProcess.running = true
}
