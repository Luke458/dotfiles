pragma Singleton

import QtQuick
import Quickshell

// Bridge to the local Luke.Quickshell.Pinentry C++ module. The module is
// optional at runtime: when it is not installed (e.g. bare `qs` without the
// import paths that scripts/qs sets up) this singleton must still load, or
// one missing module would take down every service in the qmldir. When the
// bridge is unavailable, `active` stays false and prompts are simply never
// requested by gpg-agent.
QtObject {
    id: root

    property var server: null
    readonly property bool available: server !== null
    readonly property var request: available ? server.activeRequest : null
    readonly property bool active: available ? server.active : false
    readonly property bool debug: Quickshell.env("QS_DEBUG_PINENTRY") === "1"

    function submit(password: string): void {
        if (available)
            server.submit(password);
    }

    function accept(): void {
        if (available)
            server.accept();
    }

    function reject(): void {
        if (available)
            server.reject();
    }

    function cancel(): void {
        if (available)
            server.cancel();
    }

    Component.onCompleted: {
        const component = Qt.createComponent("Luke.Quickshell.Pinentry", "PinentryServer");
        if (!component || component.status === Component.Error) {
            const reason = component ? component.errorString() : "unsupported createComponent";
            console.warn("Pinentry: QML module not available; pinentry prompts disabled (" + reason + ")");
            return;
        }

        const instance = component.createObject(root);
        if (!instance) {
            console.warn("Pinentry: could not instantiate PinentryServer");
            return;
        }

        instance.requestStarted.connect(request => { // qmllint disable signal-handler-parameters
            if (root.debug)
                console.log("Pinentry request mode:", request.mode);
        }); // qmllint enable signal-handler-parameters

        if (root.debug)
            instance.listeningChanged.connect(() => console.log("Pinentry listening:", instance.listening));

        root.server = instance;
    }
}
