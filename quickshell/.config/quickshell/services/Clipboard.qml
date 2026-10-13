pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history, captured by wl-paste --watch through the vendored
// clipboard-capture helper. Records are text or image entries; images live as
// files under ~/.local/state/quickshell/clipboard-images.
QtObject {
    id: root

    property var history: []
    property int revision: 0
    readonly property int limit: 500

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME")
        || (Quickshell.env("HOME") || "") + "/.local/state") + "/quickshell"
    readonly property string historyPath: stateDir + "/clipboard-history.json"
    readonly property string captureScript: (Quickshell.env("HOME") || "") + "/.local/bin/clipboard-capture"

    function normalize(value) {
        if (typeof value === "string")
            return value.trim().length > 0 ? { type: "text", text: value } : null;
        if (!value || typeof value !== "object")
            return null;

        const type = String(value.type || value.kind || "");
        if (type === "text") {
            const text = String(value.text || "");
            return text.trim().length > 0 ? { type: "text", text: text } : null;
        }
        if (type === "image") {
            const path = String(value.path || "");
            if (!path) return null;
            const entry = { type: "image", path: path, mime: String(value.mime || "image/png") };
            if (value.capturedAt !== undefined && value.capturedAt !== null)
                entry.capturedAt = String(value.capturedAt);
            return entry;
        }
        return null;
    }

    function entryKey(entry) {
        if (!entry) return "";
        return entry.type === "image" ? "image:" + String(entry.path || "") : "text:" + String(entry.text || "");
    }

    function addEntry(value) {
        const entry = normalize(value);
        if (!entry) return;
        const key = entryKey(entry);
        const next = [entry];
        for (let i = 0; i < history.length && next.length < limit; i++) {
            const existing = normalize(history[i]);
            if (!existing || entryKey(existing) === key) continue;
            next.push(existing);
        }
        history = next;
        revision += 1;
        save();
    }

    function addJson(line) {
        const raw = String(line || "").trim();
        if (raw === "") return;
        try {
            addEntry(JSON.parse(raw));
        } catch (error) {
            // A partial line from a torn capture; drop it.
        }
    }

    function removeAt(index) {
        const values = history;
        const target = Number(index);
        if (isNaN(target) || target < 0 || target >= values.length) return;
        const next = values.slice();
        next.splice(target, 1);
        history = next;
        revision += 1;
        save();
    }

    function clear() {
        history = [];
        revision += 1;
        save();
    }

    function loadHistory(raw) {
        let parsed = [];
        try { parsed = JSON.parse(String(raw || "[]")); } catch (error) { parsed = []; }
        const next = [];
        if (Array.isArray(parsed)) {
            for (let i = 0; i < parsed.length; i++) {
                const entry = normalize(parsed[i]);
                if (entry) next.push(entry);
            }
        }
        history = next;
        revision += 1;
    }

    function save() {
        historyFile.setText(JSON.stringify(history.slice(0, limit), null, 2) + "\n");
    }

    property FileView historyFile: FileView {
        path: root.historyPath
        atomicWrites: true
        printErrors: false
        onLoaded: root.loadHistory(text())
    }

    property Process watcher: Process {
        command: ["wl-paste", "--watch", root.captureScript]
        running: false
        stdout: SplitParser {
            onRead: line => root.addJson(line)
        }
    }

    property Process snapshot: Process {
        command: ["sh", "-c", "test -x \"$1\" && exec \"$1\"", "clipboard-capture", root.captureScript]
        running: false
        stdout: SplitParser {
            onRead: line => root.addJson(line)
        }
    }

    Component.onCompleted: {
        watcher.running = true;
        snapshot.running = true;
    }
}
