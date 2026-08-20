import QtQuick
import Quickshell
import Quickshell.Io

// Compatibility entrypoint. Password state lives only in the main shell's
// lazy picker and is discarded when that surface closes.
ShellRoot {
    Process {
        id: openProcess
        command: ["quickshell", "ipc", "call", "shell", "openPicker", "pass", "{}"]
        onExited: Qt.quit() // qmllint disable signal-handler-parameters
    }

    Component.onCompleted: openProcess.running = true
}
