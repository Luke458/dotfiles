pragma ComponentBehavior: Bound
//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "./windows"
import "./services"
import "./components" as Components

ShellRoot {
    id: root

    Component.onCompleted: {
        Qt.application.name = "quickshell";
        Qt.application.organization = "quickshell";
    }

    property bool idleInhibited: false
    property bool leftSectionExpanded: true
    readonly property int realScreenCount: Quickshell.screens.length

    IpcHandler {
        target: "shell"

        function openPicker(mode: string, payloadJson: string): string {
            return OverlayController.openPicker(mode, payloadJson);
        }

        function togglePicker(mode: string, payloadJson: string): string {
            return OverlayController.togglePicker(mode, payloadJson);
        }

        function closePicker(): void {
            OverlayController.close("ipc");
        }

        function pickerStatus(): string {
            return OverlayController.statusJson();
        }
    }

    IpcHandler {
        target: "lock"

        function lock(): string {
            Lock.requestLock();
            return Lock.statusJson();
        }

        function status(): string {
            return Lock.statusJson();
        }

        function isLocked(): bool {
            return Lock.locked;
        }

        function cancel(): bool {
            // Recovers a stuck unconfirmed lock request; refuses while the
            // session is actually locked.
            return Lock.cancelRequest();
        }
    }

    IpcHandler {
        target: "notifications"

        function toggleDnd(): bool {
            Notifications.doNotDisturb = !Notifications.doNotDisturb;
            return Notifications.doNotDisturb;
        }

        function setDnd(enabled: bool): bool {
            Notifications.doNotDisturb = enabled;
            return Notifications.doNotDisturb;
        }

        function status(): string {
            return Notifications.statusJson();
        }
    }

    IpcHandler {
        target: "bar"
        function setLauncherScreen(screenName: string): void {
            if (screenName === "") {
                OverlayController.close("legacy-lease");
            } else {
                OverlayController.openPicker("launcher", "{}");
                OverlayController.targetScreenName = screenName;
            }
        }

        function lock(): void {
            Lock.requestLock();
        }

        function togglePowerMenu(): void {
            OverlayController.togglePicker("power", "{}");
        }
    }

    Process {
        id: inhibitorProc
        command: ["systemd-inhibit", "--what=idle", "--why=Quickshell Toggle", "--mode=block", "sleep", "infinity"]
        running: root.idleInhibited
    }

    Instantiator {
        model: Quickshell.screens
        delegate: Bar {
            required property var modelData
            screen: modelData
            inhibited: root.idleInhibited
            leftSectionExpanded: root.leftSectionExpanded
            onToggleInhibitor: root.idleInhibited = !root.idleInhibited
            onToggleLeftSection: root.leftSectionExpanded = !root.leftSectionExpanded
        }
    }

    Instantiator {
        model: Quickshell.screens
        delegate: Item {
            id: pickerHost
            required property var modelData
            visible: false

            LazyLoader {
                active: OverlayController.opened
                    && pickerHost.modelData
                    && pickerHost.modelData.name === OverlayController.targetScreenName

                Components.PickerOverlay {
                    screen: pickerHost.modelData
                    mode: OverlayController.mode
                    payload: OverlayController.payload
                    requestSerial: OverlayController.requestSerial
                    onRequestClose: reason => OverlayController.close(reason)
                }
            }
        }
    }

    Instantiator {
        model: Quickshell.screens
        delegate: Components.NotificationOverlay {
            required property var modelData
            screen: modelData
            activeMonitor: Hyprland.focusedMonitor && modelData.name === Hyprland.focusedMonitor.name
        }
    }

    Instantiator {
        model: Quickshell.screens
        delegate: Components.PolkitAuthOverlay {
            required property var modelData
            screen: modelData
            activeMonitor: Hyprland.focusedMonitor && modelData.name === Hyprland.focusedMonitor.name
        }
    }

    Instantiator {
        model: Quickshell.screens
        delegate: Components.PinentryOverlay {
            required property var modelData
            screen: modelData
            activeMonitor: Hyprland.focusedMonitor && modelData.name === Hyprland.focusedMonitor.name
        }
    }

    WlSessionLock {
        id: sessionLock
        locked: Lock.requested && root.realScreenCount > 0
        onLockedChanged: Lock.updateSessionState(locked, secure)
        onSecureChanged: Lock.updateSessionState(locked, secure)

        WlSessionLockSurface {
            Lockscreen {
                anchors.fill: parent
            }
        }
    }
}
