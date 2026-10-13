pragma Singleton

import QtQuick

QtObject {
    id: root

    // On-screen display state. The overlay components render this on the
    // focused monitor; everything is input-transparent there.
    property bool visible: false
    property string iconKey: ""
    property real value: -1 // < 0 selects message mode
    property real maxValue: 100
    property string message: ""
    property string progressText: ""
    property int durationMs: 1200

    function showProgress(icon, value, maxValue, progressText, duration) {
        root.iconKey = String(icon || "");
        root.value = Number(value);
        root.maxValue = Number(maxValue) > 0 ? Number(maxValue) : 100;
        root.progressText = progressText === undefined ? "" : String(progressText);
        root.message = "";
        root.durationMs = Math.max(400, Number(duration) || 1200);
        root.present();
    }

    function showMessage(icon, message, duration) {
        root.iconKey = String(icon || "");
        root.value = -1;
        root.maxValue = 100;
        root.progressText = "";
        root.message = String(message || "");
        root.durationMs = Math.max(400, Number(duration) || 1200);
        root.present();
    }

    // IPC entry point. Payload shape:
    // { icon, value, max, message, progressText, duration }
    function show(payloadJson) {
        let payload = {};
        try {
            payload = JSON.parse(String(payloadJson || "{}")) || {};
        } catch (error) {
            return JSON.stringify({ ok: false, error: "invalid payload" });
        }
        if (!payload || typeof payload !== "object")
            return JSON.stringify({ ok: false, error: "invalid payload" });

        if (payload.value !== undefined && payload.value !== null && isFinite(Number(payload.value))) {
            showProgress(
                payload.icon,
                Number(payload.value),
                payload.max !== undefined ? Number(payload.max) : 100,
                payload.progressText,
                payload.duration
            );
        } else {
            showMessage(payload.icon, payload.message, payload.duration);
        }
        return JSON.stringify({ ok: true });
    }

    function close() {
        visible = false;
    }

    function statusJson() {
        return JSON.stringify({
            visible: visible,
            icon: iconKey,
            value: value,
            max: maxValue,
            message: message
        });
    }

    function present() {
        visible = true;
        autoHideTimer.interval = durationMs;
        autoHideTimer.restart();
    }

    property Timer autoHideTimer: Timer {
        repeat: false
        onTriggered: root.visible = false
    }
}
