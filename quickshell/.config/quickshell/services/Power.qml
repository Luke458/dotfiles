pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

QtObject {
    id: root

    component PowerCommand: Process {
        id: actionProcess
        required property string actionName
        property string failureText: ""
        property bool awaitingResult: false

        function start(): void {
            if (running)
                return;
            failureText = "";
            awaitingResult = true;
            running = true;
            Qt.callLater(checkStartFailure);
        }

        function checkStartFailure(): void {
            if (!running && awaitingResult) {
                awaitingResult = false;
                root.reportFailure(actionName, "Could not start " + command[0]);
            }
        }

        onRunningChanged: {
            if (!running)
                Qt.callLater(checkStartFailure);
        }
        onStarted: failureText = ""
        stderr: SplitParser {
            onRead: data => actionProcess.failureText = (actionProcess.failureText + data + "\n").slice(-1000)
        }
        onExited: (exitCode, exitStatus) => { // qmllint disable signal-handler-parameters
            awaitingResult = false;
            if (exitCode !== 0 || exitStatus !== 0)
                root.reportFailure(actionName, failureText.trim() || "Command exited with status " + exitCode);
        }
    }

    function reportFailure(action: string, detail: string): void {
        console.error("Power: " + action + " failed: " + detail);
        Quickshell.execDetached(["notify-send", "--", action + " failed", detail]);
    }

    property PowerCommand poweroffProc: PowerCommand { actionName: "Shutdown"; command: ["systemctl", "poweroff"] }
    property PowerCommand rebootProc: PowerCommand { actionName: "Reboot"; command: ["systemctl", "reboot"] }
    property PowerCommand suspendProc: PowerCommand { actionName: "Suspend"; command: ["systemctl", "suspend"] }
    property PowerCommand logoutProc: PowerCommand { actionName: "Logout"; command: ["uwsm", "stop"] }
    property bool suspendPending: false

    property Timer displayOffDelay: Timer {
        interval: 1000
        onTriggered: Hyprland.dispatch(Hyprland.usingLua
            ? "hl.dsp.dpms({ action = \"disable\" })"
            : "dpms off")
    }

    property Timer suspendDeadline: Timer {
        interval: 4000
        onTriggered: {
            if (!root.suspendPending)
                return;

            root.suspendPending = false;
            console.error("Power: refusing to suspend because the session lock did not become secure");
            Quickshell.execDetached(["notify-send", "Suspend cancelled", "The session lock did not become secure."]);
        }
    }

    property Connections lockConnections: Connections {
        target: Lock

        function onSecureChanged(): void {
            if (Lock.secure)
                root.completeSuspend();
        }
    }

    function poweroff() { poweroffProc.start(); }
    function reboot() { rebootProc.start(); }

    function suspend(): void {
        if (suspendPending || suspendProc.running)
            return;

        suspendPending = true;
        Lock.requestLock();
        if (Lock.secure)
            completeSuspend();
        else
            suspendDeadline.restart();
    }

    function completeSuspend(): void {
        if (!suspendPending || !Lock.secure || suspendProc.running)
            return;

        suspendPending = false;
        suspendDeadline.stop();
        suspendProc.start();
    }

    function logout() { logoutProc.start(); }
    function lock() { Lock.requestLock(); }
    function displayOff() { displayOffDelay.restart(); }
}
