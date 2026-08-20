pragma Singleton

import Quickshell
import Luke.Quickshell.Pinentry

PinentryServer {
    id: server

    readonly property var request: activeRequest // qmllint disable unresolved-type
    readonly property bool debug: Quickshell.env("QS_DEBUG_PINENTRY") === "1"

    onListeningChanged: {
        if (debug)
            console.log("Pinentry listening:", listening)
    }
    onRequestStarted: (pinentryRequest) => {
        if (debug)
            console.log("Pinentry request mode:", pinentryRequest.mode);
    }
}
