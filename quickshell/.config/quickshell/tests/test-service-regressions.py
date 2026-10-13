#!/usr/bin/env python3
"""Run service failure paths in an isolated, windowless Quickshell instance."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

def check(condition, detail):
    # Deliberately not `assert`: CPython strips assert statements under -O, so
    # an optimized run would report success having verified nothing.
    if not condition:
        raise SystemExit(f"FAILED: {detail}")



ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix="qs-service-test-") as directory:
    test = Path(directory)
    for name in ("Power", "Notifications", "Network", "Media", "AttackSharkMetrics"):
        shutil.copyfile(ROOT / "services" / (name + ".qml"), test / (name + ".qml"))
    (test / "qmldir").write_text("""singleton Power Power.qml
singleton Notifications Notifications.qml
singleton NetworkService Network.qml
singleton Media Media.qml
singleton AttackSharkMetrics AttackSharkMetrics.qml
singleton Lock Lock.qml
""")
    (test / "Lock.qml").write_text("""pragma Singleton
import QtQuick
QtObject {
    property bool secure: false
    function requestLock() {} 
}
""")
    binary = test / "bin"
    binary.mkdir()
    notify = binary / "notify-send"
    notify.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$TEST_NOTIFICATIONS"\n')
    notify.chmod(0o755)
    (test / "shell.qml").write_text(r'''import QtQuick
import Quickshell
import Quickshell.Networking
import "."
ShellRoot {
    id: root
    property int failures: 0
    property int closed: 0
    property int serial: 0
    property var items: []
    property QtObject fakeServer: QtObject { signal notification(var value) }
    property QtObject wifi1: QtObject {
        property int type: DeviceType.Wifi
        property bool connected: true
        property bool scannerEnabled: false
        property string address: "wifi-address"
        property var networks: ({values: []})
    }
    property QtObject wifi2: QtObject {
        property int type: DeviceType.Wifi
        property bool connected: true
        property bool scannerEnabled: false
        property string address: "wifi2-address"
        property var networks: ({values: []})
    }
    property QtObject wired: QtObject {
        property int type: DeviceType.Wired
        property bool connected: true
        property string address: "wired-address"
    }
    function check(ok, message) {
        if (!ok) { failures++; console.error("FAIL: " + message); }
    }
    function makeNotification(transient, timeout) {
        const handlers = [];
        const signal = {connect: function(callback) {}};
        const n = {
            id: ++serial, tracked: false, summary: "test", body: "", appIcon: "",
            appName: "test", desktopEntry: "", urgency: 1, transient: transient,
            expireTimeout: timeout, closed: {connect: callback => handlers.push(callback)},
            summaryChanged: signal, bodyChanged: signal, appIconChanged: signal,
            appNameChanged: signal, desktopEntryChanged: signal, urgencyChanged: signal,
            transientChanged: signal, expireTimeoutChanged: signal,
            expire: function() { this.close(); }, dismiss: function() { this.close(); },
            close: function() {
                if (!this.tracked) return;
                this.tracked = false;
                root.closed++;
                for (const callback of handlers) callback(1);
            }
        };
        items.push(n);
        return n;
    }
    Timer {
        interval: 150; running: true
        onTriggered: {
            Notifications.server = root.fakeServer;
            for (let i = 0; i < 55; i++) root.fakeServer.notification(root.makeNotification(true, 0));
            root.check(root.closed === 5, "overflow must close five server notifications");
            root.check(root.items.filter(n => n.tracked).length === 50, "server retention bound");
            Notifications.clearAll();
            root.check(root.items.every(n => !n.tracked), "clearAll includes transient notifications");
            root.fakeServer.notification(root.makeNotification(false, 1000));
            Notifications.clearPopups();
            Notifications.doNotDisturb = true;
            root.fakeServer.notification(root.makeNotification(true, 1000));
            NetworkService._devices = [root.wifi1, root.wired];
            root.check(NetworkService.activeDevice === root.wired && NetworkService.address === "wired-address", "consistent active device");
            NetworkService.beginDetails();
            root.check(root.wifi1.scannerEnabled, "scan when details open");
            NetworkService._devices = [root.wifi2, root.wired];
            root.check(!root.wifi1.scannerEnabled && root.wifi2.scannerEnabled, "scanner follows replacement device");
            NetworkService.endDetails();
            root.check(!root.wifi2.scannerEnabled, "scanner stops on close");
            Power.poweroffProc.command = ["sh", "-c", "echo simulated-denial >&2; exit 7"];
            Power.poweroff();
            Power.rebootProc.command = ["/nonexistent/quickshell-test-command"];
            Power.reboot();
            root.check(!Media.positionTimer.running, "unobserved media timer is stopped");
            // This tree has no scripts/attack-shark-metrics, so the helper
            // cannot be exec'd. Instantiate it here and assert the reported
            // failure in the finish timer, once the async detection has run.
            root.check(AttackSharkMetrics.loading, "attack shark helper starts out loading");
            finish.start();
        }
    }
    Timer {
        id: finish; interval: 1400
        onTriggered: {
            root.check(root.items.every(n => !n.tracked), "hidden and DND notifications expire");
            root.check(Notifications.history.count === 1, "expiration preserves history snapshot");
            root.check(Object.keys(Notifications.popupTimers).length === 0, "timers cleaned up");
            root.check(AttackSharkMetrics.hasError, "unstartable helper reports an error instead of staying blank");
            root.check(/^Could not start/.test(AttackSharkMetrics.errorMessage),
                       "start failure names the helper: " + AttackSharkMetrics.errorMessage);
            console.log("SERVICE_TEST_RESULT " + root.failures);
            Qt.quit();
        }
    }
}
''')
    runtime = test / "runtime"
    runtime.mkdir(mode=0o700)
    env = dict(os.environ, XDG_RUNTIME_DIR=str(runtime), QT_QPA_PLATFORM="offscreen", QS_NOTIFICATION_SERVER="off",
               XDG_STATE_HOME=str(test / "state"), HYPRLAND_INSTANCE_SIGNATURE="",
               TEST_NOTIFICATIONS=str(test / "notifications"), PATH=str(binary) + ":" + os.environ["PATH"])
    try:
        result = subprocess.run(["qs", "-p", str(test)], env=env, capture_output=True, text=True, timeout=15)
    except subprocess.TimeoutExpired as error:
        print(error.stdout, error.stderr)
        raise
    output = result.stdout + result.stderr
    print(output)
    check(result.returncode == 0 and "SERVICE_TEST_RESULT 0" in output,
          (result.returncode, output))
    notifications = (test / "notifications").read_text()
    check("simulated-denial" in notifications, notifications)
    check("Could not start /nonexistent/quickshell-test-command" in notifications,
          notifications)
    print("service regressions passed (including power denial and missing executable)")
