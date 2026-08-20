pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Polkit

QtObject {
    id: root

    readonly property bool disabled: Quickshell.env("QS_DISABLE_POLKIT") === "1"
    readonly property bool available: !disabled && agent !== null
    readonly property bool registered: available && agent.isRegistered
    readonly property bool active: registered && agent.isActive
    readonly property var flow: available ? agent.flow : null
    // Avoid colliding with stale agents from older Quickshell processes while
    // keeping the path stable across QML reloads in the same process.
    readonly property string agentPath: "/org/quickshell/PolkitAgent_" + Quickshell.processId
    property var agent: null

    property Component agentComponent: Component {
        PolkitAgent {
            path: root.agentPath

            Component.onCompleted: {
                console.log("Polkit: agent created at", path, "registered =", isRegistered);
            }

            onIsRegisteredChanged: {
                console.log("Polkit: registered =", isRegistered);
            }

            onIsActiveChanged: {
                console.log("Polkit: active =", isActive);
            }

            onAuthenticationRequestStarted: {
                console.log("Polkit: authentication request started", flow ? flow.actionId : ""); // qmllint disable unresolved-type
            }
        }
    }

    property Timer registrationCheckTimer: Timer {
        interval: 1500
        repeat: false
        onTriggered: {
            if (!root.registered) {
                console.warn("Polkit: agent did not register; pkexec will fall back to terminal authentication");
            }
        }
    }

    function createAgent() {
        if (!root.disabled && root.agent === null) {
            root.agent = agentComponent.createObject(root);
            if (root.agent === null) {
                console.warn("Polkit: failed to create agent object", agentComponent.errorString());
            } else {
                registrationCheckTimer.restart();
            }
        } else if (root.disabled) {
            console.log("Polkit: disabled by QS_DISABLE_POLKIT=1");
        }
    }

    function submit(response) {
        if (root.flow) {
            root.flow.submit(response);
        }
    }

    function cancel() {
        if (root.flow) {
            root.flow.cancelAuthenticationRequest();
        }
    }

    Component.onCompleted: createAgent()
}
