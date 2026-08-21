pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

QtObject {
    id: root

    property bool opened: false
    property string mode: ""
    property string targetScreenName: ""
    property var payload: ({})
    property int requestSerial: 0

    readonly property var allowedModes: ({
        launcher: true,
        pass: true,
        power: true,
        menu: true,
        emoji: true
    })

    function focusedScreenName() {
        if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name)
            return Hyprland.focusedMonitor.name;
        return Quickshell.screens.length > 0 && Quickshell.screens[0] ? Quickshell.screens[0].name : "";
    }

    function parsePayload(payloadJson) {
        if (!payloadJson)
            return ({});
        try {
            const parsed = JSON.parse(payloadJson);
            return parsed && typeof parsed === "object" ? parsed : ({});
        } catch (error) {
            console.warn("OverlayController: invalid picker payload: " + error);
            return ({});
        }
    }

    function openPicker(pickerMode, payloadJson) {
        const normalizedMode = String(pickerMode || "").toLowerCase();
        if (!allowedModes[normalizedMode])
            return JSON.stringify({ ok: false, error: "unsupported picker mode" });

        const screenName = focusedScreenName();
        if (!screenName)
            return JSON.stringify({ ok: false, error: "no screen available" });

        mode = normalizedMode;
        payload = parsePayload(payloadJson);
        targetScreenName = screenName;
        requestSerial += 1;
        opened = true;
        return JSON.stringify({ ok: true, mode: mode, screen: targetScreenName });
    }

    function togglePicker(pickerMode, payloadJson) {
        const normalizedMode = String(pickerMode || "").toLowerCase();
        if (opened && mode === normalizedMode) {
            close("toggle");
            return JSON.stringify({ ok: true, opened: false });
        }
        return openPicker(normalizedMode, payloadJson);
    }

    function close(reason) {
        console.log("OverlayController: closing picker (" + (reason || "unspecified") + ")");
        opened = false;
        mode = "";
        targetScreenName = "";
        payload = ({});
    }

    function statusJson() {
        return JSON.stringify({
            opened: opened,
            mode: mode,
            screen: targetScreenName,
            requestSerial: requestSerial
        });
    }
}
