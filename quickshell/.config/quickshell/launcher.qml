import QtQuick
import Quickshell
import Quickshell.Io

// Compatibility entrypoint. The real picker is a lazy surface in shell.qml.
ShellRoot {
    id: root
    readonly property string menuFile: Quickshell.env("QS_MENU_FILE") || ""
    readonly property string mode: menuFile ? "menu" : "launcher"
    readonly property string payload: JSON.stringify({
        file: menuFile,
        prompt: Quickshell.env("QS_MENU_PROMPT") || (menuFile ? "Select:" : "Run:")
    })

    Process {
        id: openProcess
        command: ["quickshell", "ipc", "call", "shell", "openPicker", root.mode, root.payload]
        onExited: Qt.quit() // qmllint disable signal-handler-parameters
    }

    Component.onCompleted: openProcess.running = true
}
