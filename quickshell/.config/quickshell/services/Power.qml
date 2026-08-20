pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

QtObject {
    id: root

    property Process poweroffProc: Process { command: ["systemctl", "poweroff"] }
    property Process rebootProc: Process { command: ["systemctl", "reboot"] }
    property Process suspendProc: Process { command: ["systemctl", "suspend"] }
    property Process logoutProc: Process { command: ["uwsm", "stop"] }
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

    function poweroff() { poweroffProc.running = true; }
    function reboot() { rebootProc.running = true; }

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
        suspendProc.running = true;
    }

    function logout() { logoutProc.running = true; }
    function lock() { Lock.requestLock(); }
    function displayOff() { displayOffDelay.restart(); }
}
