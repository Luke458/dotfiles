pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications

QtObject {
    id: root

    readonly property string serverMode: Quickshell.env("QS_DISABLE_NOTIFICATION_SERVER") === "1"
        ? "off"
        : (Quickshell.env("QS_NOTIFICATION_SERVER") || "auto")
    readonly property bool debug: Quickshell.env("QS_DEBUG_NOTIFICATIONS") === "1"
    property var server: null
    property Component serverComponent: Component {
        NotificationServer {
            keepOnReload: false
            persistenceSupported: true
            // The current card UI only supports the conventional default
            // activation action and plain text.
            actionsSupported: false
            actionIconsSupported: false
            bodyImagesSupported: false
            imageSupported: false
            inlineReplySupported: false
        }
    }
    property Component autoDismissTimerComponent: Component {
        Timer {
            repeat: false
        }
    }
    
    // Full history of notifications
    property ListModel history: ListModel {}
    
    // Currently active popups (toasts)
    property ListModel popups: ListModel {}
    
    property int unreadCount: 0
    property bool doNotDisturb: false
    property var liveNotifications: ({})
    property var unreadNotifications: ({})
    property var popupTimers: ({})
    // Insertion order for liveNotifications so stale entries can be evicted
    // when apps never send CloseNotification.
    property var liveOrder: []
    readonly property int maximumHistoryItems: 200
    readonly property int maximumTrackedNotifications: 50
    readonly property int maximumVisiblePopups: 5
    readonly property string stateDirectory: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/quickshell"
    readonly property string stateFile: stateDirectory + "/notifications.json"
    property bool stateReady: false
    property bool hydratingState: false
    property Component detachedProcessComponent: Component {
        Process {}
    }

    onDoNotDisturbChanged: schedulePersist()

    property Process stateDirectoryProcess: Process {
        command: ["mkdir", "-p", root.stateDirectory]
        running: true
        onExited: (exitCode) => { // qmllint disable signal-handler-parameters
            root.stateReady = exitCode === 0;
        }
    }

    property FileView persistenceFile: FileView {
        path: root.stateReady ? root.stateFile : ""
        atomicWrites: true
        watchChanges: false
        printErrors: false

        onLoaded: root.restoreState(text())
        onLoadFailed: error => { // qmllint disable signal-handler-parameters
            if (root.stateReady) {
                root.hydratingState = false;
                root.persistState();
            }
        }
    }

    property Timer persistTimer: Timer {
        interval: 250
        repeat: false
        onTriggered: root.persistState()
    }

    property Process ownerCheck: Process {
        command: [
            "sh",
            "-c",
            "owner=$(busctl --user call org.freedesktop.DBus / org.freedesktop.DBus GetNameOwner s org.freedesktop.Notifications 2>/dev/null) || exit 0\n" +
            "owner=${owner#*\\\"}\n" +
            "owner=${owner%\\\"*}\n" +
            "pid=$(busctl --user call org.freedesktop.DBus / org.freedesktop.DBus GetConnectionUnixProcessID s \"$owner\" 2>/dev/null) || exit 0\n" +
            "pid=${pid#u }\n" +
            "[ \"$pid\" = \"$1\" ] && exit 0\n" +
            "exit 2",
            "notification-owner-check",
            String(Quickshell.processId)
        ]
        running: false
        stdout: StdioCollector {}

        onExited: (exitCode) => { // qmllint disable signal-handler-parameters
            if (root.serverMode === "off") return;
            if (root.serverMode === "on" || exitCode === 0) {
                root.createServer();
            } else if (root.debug) {
                console.log("Notifications: external notification server detected; Quickshell server disabled");
            }
        }
    }

    property Timer ownerCheckDelay: Timer {
        interval: 250
        repeat: false
        onTriggered: ownerCheck.running = true
    }

    property Connections serverConnections: Connections {
        target: root.server
        enabled: root.server !== null
        
        function onNotification(notification) {
            notification.tracked = true;
            if (root.debug) {
                console.log("Notifications: Received from " + (notification.appName || "unknown") + ": " + notification.summary);
            }

            const trackingId = notification.id + "_" + Date.now();

            root.liveNotifications[trackingId] = notification;
            root.liveOrder.push(trackingId);
            while (root.liveOrder.length > root.maximumTrackedNotifications) {
                const evicted = root.liveOrder.shift();
                if (evicted !== trackingId) {
                    delete root.liveNotifications[evicted];
                    root.removeFromPopupsById(evicted);
                }
            }
            const item = root.notificationItem(notification, trackingId);

            // Transient notifications may be shown as toasts, but must not be
            // persisted in the notification center.
            if (!notification.transient) {
                root.history.insert(0, item);
                root.setNotificationUnread(trackingId, true);
                root.trimHistory();
            }
            const showPopup = !root.doNotDisturb || notification.urgency === NotificationUrgency.Critical;
            if (showPopup) {
                root.popups.insert(0, item);
                root.trimPopups();
            }

            const updateSnapshot = () => root.updateNotificationSnapshot(trackingId, notification);
            notification.summaryChanged.connect(updateSnapshot);
            notification.bodyChanged.connect(updateSnapshot);
            notification.appIconChanged.connect(updateSnapshot);
            notification.appNameChanged.connect(updateSnapshot);
            notification.desktopEntryChanged.connect(updateSnapshot);
            notification.urgencyChanged.connect(updateSnapshot);
            notification.transientChanged.connect(updateSnapshot);
            notification.expireTimeoutChanged.connect(updateSnapshot);

            // Server-side closes should only remove active toasts. Keep a
            // snapshot in history until the user explicitly clears it.
            notification.closed.connect((reason) => {
                root.handleNotificationClosed(trackingId);
            });

            if (showPopup)
                root.schedulePopupTimeout(trackingId, notification);
            root.schedulePersist();
        }
    }

    function popupTimeoutMs(notification) {
        const requested = Number(notification ? notification.expireTimeout : -1);
        if (requested === 0)
            return 0;
        if (requested > 0)
            return Math.max(1000, requested);
        if (notification && notification.urgency === NotificationUrgency.Critical)
            return 0;
        return 10000;
    }

    function notificationItem(notification, trackingId) {
        return {
            "summary": notification.summary,
            "body": notification.body,
            "appIcon": notification.appIcon,
            "appName": notification.appName,
            "desktopEntry": notification.desktopEntry,
            "id": notification.id,
            "trackingId": trackingId,
            "urgency": notification.urgency,
            "timeoutMs": popupTimeoutMs(notification),
            "time": new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
        };
    }

    function updateModelItem(model, trackingId, item) {
        for (var i = 0; i < model.count; i++) {
            if (model.get(i).trackingId === trackingId) {
                for (const key in item)
                    model.setProperty(i, key, item[key]);
                return true;
            }
        }
        return false;
    }

    function updateNotificationSnapshot(trackingId, notification) {
        // Once a notification has been closed or dismissed it must not
        // resurrect in history via late property updates on the tracked object.
        if (!root.liveNotifications[trackingId])
            return;
        const item = notificationItem(notification, trackingId);
        const hasHistoryItem = updateModelItem(history, trackingId, item);
        const hasPopupItem = updateModelItem(popups, trackingId, item);

        if (notification.transient && hasHistoryItem) {
            removeFromHistoryById(trackingId);
        } else if (!notification.transient && !hasHistoryItem) {
            history.insert(0, item);
            setNotificationUnread(trackingId, true);
            trimHistory();
        }

        if (hasPopupItem)
            schedulePopupTimeout(trackingId, notification);
        schedulePersist();
    }

    function schedulePopupTimeout(trackingId, notification) {
        cancelPopupTimer(trackingId);
        const timeout = popupTimeoutMs(notification);
        if (timeout <= 0)
            return;

        const timer = autoDismissTimerComponent.createObject(root, { interval: timeout });
        popupTimers[trackingId] = timer;
        timer.triggered.connect(() => {
            delete root.popupTimers[trackingId];
            root.removeFromPopupsById(trackingId);
            timer.destroy();
        });
        timer.start();
    }

    function cancelPopupTimer(trackingId) {
        const timer = popupTimers[trackingId];
        if (timer) {
            delete popupTimers[trackingId];
            timer.stop();
            timer.destroy();
        }
    }

    function trimHistory() {
        while (history.count > maximumHistoryItems) {
            const item = history.get(history.count - 1);
            if (item)
                setNotificationUnread(item.trackingId, false);
            history.remove(history.count - 1);
        }
        schedulePersist();
    }

    function trimPopups() {
        // Bound the toast stack: prefer dropping the oldest non-critical
        // popup; only fall back to a critical when everything is critical.
        while (popups.count > maximumVisiblePopups) {
            let index = -1;
            for (let i = popups.count - 1; i >= 0; i--) {
                const candidate = popups.get(i);
                if (candidate && Number(candidate.urgency) !== NotificationUrgency.Critical) {
                    index = i;
                    break;
                }
            }
            if (index < 0)
                index = popups.count - 1;
            const victim = popups.get(index);
            if (!victim)
                break;
            removeFromPopupsById(victim.trackingId);
        }
    }

    function removeByTrackingId(trackingId) {
        removeFromHistoryById(trackingId);
        removeFromPopupsById(trackingId);
    }

    function forgetLiveNotification(trackingId) {
        delete root.liveNotifications[trackingId];
        const index = root.liveOrder.indexOf(trackingId);
        if (index >= 0)
            root.liveOrder.splice(index, 1);
    }

    function handleNotificationClosed(trackingId) {
        root.forgetLiveNotification(trackingId);
        removeFromPopupsById(trackingId);
    }

    function removeFromHistoryById(trackingId) {
        for (var i = 0; i < history.count; i++) {
            const item = history.get(i);
            if (item && item.trackingId === trackingId) {
                root.setNotificationUnread(trackingId, false);
                history.remove(i);
                schedulePersist();
                break;
            }
        }
    }

    function removeFromPopupsById(trackingId) {
        cancelPopupTimer(trackingId);
        for (var i = 0; i < popups.count; i++) {
            if (popups.get(i).trackingId === trackingId) {
                popups.remove(i);
                break;
            }
        }
    }

    // Dismiss a notification via the server
    function dismiss(notification) {
        let trackingId = "";
        for (var i = 0; i < history.count; i++) {
            const item = history.get(i);
            if (item && root.liveNotifications[item.trackingId] === notification) {
                trackingId = item.trackingId;
                break;
            }
        }

        if (notification) {
            try {
                notification.dismiss();
            } catch (e) {}
        }
        
        if (trackingId) {
            removeByTrackingId(trackingId);
        }
    }

    function dismissByTrackingId(trackingId) {
        const notification = root.liveNotifications[trackingId];
        if (notification) {
            try {
                notification.dismiss();
            } catch (e) {}
        }

        root.forgetLiveNotification(trackingId);
        removeByTrackingId(trackingId);
    }

    function clearAll() {
        for (var i = history.count - 1; i >= 0; i--) {
            const item = history.get(i);
            const notification = item ? root.liveNotifications[item.trackingId] : null;
            if (notification) {
                try {
                    notification.dismiss();
                } catch (e) {}
            }
        }
        root.liveNotifications = ({});
        root.liveOrder = [];
        root.unreadNotifications = ({});
        for (const trackingId in root.popupTimers)
            root.cancelPopupTimer(trackingId);
        history.clear();
        popups.clear();
        root.unreadCount = 0;
        schedulePersist();
    }

    function clearPopups() {
        for (const trackingId in root.popupTimers)
            root.cancelPopupTimer(trackingId);
        popups.clear();
    }

    function historyItemByTrackingId(trackingId) {
        for (var i = 0; i < history.count; i++) {
            const item = history.get(i);
            if (item && item.trackingId === trackingId) {
                return item;
            }
        }

        return null;
    }

    function popupItemByTrackingId(trackingId) {
        for (var i = 0; i < popups.count; i++) {
            const item = popups.get(i);
            if (item && item.trackingId === trackingId) {
                return item;
            }
        }

        return null;
    }

    function normalizeAppId(value) {
        if (value === undefined || value === null) {
            return "";
        }

        let text = String(value).toLowerCase().trim();
        if (text === "") {
            return "";
        }

        const slashIndex = text.lastIndexOf("/");
        if (slashIndex >= 0) {
            text = text.substring(slashIndex + 1);
        }

        if (text.endsWith(".desktop")) {
            text = text.substring(0, text.length - 8);
        }

        return text;
    }

    function compactAppId(value) {
        return root.normalizeAppId(value).replace(/[^a-z0-9]/g, "");
    }

    function activationCandidates(notification, item) {
        const seen = {};
        const candidates = [];
        const ignored = {
            "": true,
            "app": true,
            "application": true,
            "com": true,
            "desktop": true,
            "electron": true,
            "io": true,
            "net": true,
            "notify-send": true,
            "org": true,
            "quickshell": true
        };

        function add(value) {
            const normalized = root.normalizeAppId(value);
            if (ignored[normalized] || seen[normalized]) {
                return;
            }

            seen[normalized] = true;
            candidates.push(normalized);

            const compact = root.compactAppId(normalized);
            if (compact && !ignored[compact] && !seen[compact]) {
                seen[compact] = true;
                candidates.push(compact);
            }

            const parts = normalized.split(/[._ -]+/);
            for (var i = 0; i < parts.length; i++) {
                const part = parts[i];
                if (part.length >= 3 && !ignored[part] && !seen[part]) {
                    seen[part] = true;
                    candidates.push(part);
                }
            }
        }

        if (notification) {
            add(notification.desktopEntry);
            add(notification.appName);
            add(notification.appIcon);
        }

        if (item) {
            add(item.desktopEntry);
            add(item.appName);
            add(item.appIcon);
        }

        return candidates;
    }

    function toplevelIdentifiers(toplevel) {
        const ipc = toplevel ? (toplevel.lastIpcObject || {}) : {};
        const identifiers = [
            ipc.class || "",
            ipc.initialClass || "",
            toplevel && toplevel.wayland ? (toplevel.wayland.appId || "") : ""
        ];

        return identifiers;
    }

    function appIdMatchScore(candidate, identifier) {
        const candidateId = root.normalizeAppId(candidate);
        const identifierId = root.normalizeAppId(identifier);
        if (!candidateId || !identifierId) {
            return 0;
        }

        if (candidateId === identifierId) {
            return 100;
        }

        const compactCandidate = root.compactAppId(candidateId);
        const compactIdentifier = root.compactAppId(identifierId);
        if (compactCandidate && compactCandidate === compactIdentifier) {
            return 90;
        }

        if (candidateId.length >= 5 && identifierId.length >= 5
                && (identifierId.indexOf(candidateId) >= 0 || candidateId.indexOf(identifierId) >= 0)) {
            return 70;
        }

        if (compactCandidate.length >= 5 && compactIdentifier.length >= 5
                && (compactIdentifier.indexOf(compactCandidate) >= 0 || compactCandidate.indexOf(compactIdentifier) >= 0)) {
            return 60;
        }

        return 0;
    }

    function findMatchingToplevel(notification, item) {
        const candidates = root.activationCandidates(notification, item);
        if (candidates.length === 0 || !Hyprland.toplevels || !Hyprland.toplevels.values) {
            return null;
        }

        const toplevels = Array.from(Hyprland.toplevels.values);
        let bestToplevel = null;
        let bestScore = 0;

        for (var i = 0; i < toplevels.length; i++) {
            const toplevel = toplevels[i];
            const identifiers = root.toplevelIdentifiers(toplevel);
            let score = 0;

            for (var c = 0; c < candidates.length; c++) {
                for (var id = 0; id < identifiers.length; id++) {
                    score = Math.max(score, root.appIdMatchScore(candidates[c], identifiers[id]));
                }
            }

            if (toplevel && toplevel.urgent) {
                score += 5;
            }

            if (score > bestScore) {
                bestScore = score;
                bestToplevel = toplevel;
            }
        }

        return bestScore >= 60 ? bestToplevel : null;
    }

    function luaString(value) {
        return "\"" + String(value)
            .replace(/\\/g, "\\\\")
            .replace(/"/g, "\\\"")
            .replace(/\n/g, "\\n")
            .replace(/\r/g, "\\r") + "\"";
    }

    function focusToplevel(toplevel) {
        if (!toplevel || !toplevel.address) {
            return false;
        }

        let address = String(toplevel.address);
        if (!address.startsWith("0x")) {
            address = "0x" + address;
        }

        // Hyprland builds with Lua support evaluate dispatch() as Lua code;
        // the raw shell-style form fails with a syntax error there.
        if (Hyprland.usingLua) {
            Hyprland.dispatch("hl.dsp.focuswindow(" + root.luaString("address:" + address) + ")");
        } else {
            Hyprland.dispatch("focuswindow address:" + address);
        }
        return true;
    }

    function invokeDefaultAction(notification) {
        if (!notification || !notification.actions) {
            return false;
        }

        for (var i = 0; i < notification.actions.length; i++) {
            const action = notification.actions[i];
            if (action && action.identifier === "default") {
                action.invoke();
                return true;
            }
        }

        return false;
    }

    function desktopEntryFor(notification, item) {
        const entry = notification && notification.desktopEntry
            ? notification.desktopEntry
            : (item && item.desktopEntry ? item.desktopEntry : "");

        return root.normalizeAppId(entry);
    }

    function launchDesktopEntry(desktopEntry) {
        const entry = root.normalizeAppId(desktopEntry);
        if (!entry) {
            return false;
        }

        const process = root.detachedProcessComponent.createObject(root);
        process.command = ["gtk-launch", entry];
        process.startDetached();
        process.destroy();
        return true;
    }

    function activateByTrackingId(trackingId) {
        if (!trackingId) {
            return false;
        }

        const notification = root.liveNotifications[trackingId] || null;
        const item = root.historyItemByTrackingId(trackingId) || root.popupItemByTrackingId(trackingId);

        if (root.invokeDefaultAction(notification)) {
            root.setNotificationUnread(trackingId, false);
            root.removeFromPopupsById(trackingId);
            return true;
        }

        const toplevel = root.findMatchingToplevel(notification, item);
        if (root.focusToplevel(toplevel)) {
            root.setNotificationUnread(trackingId, false);
            root.removeFromPopupsById(trackingId);
            return true;
        }

        if (root.launchDesktopEntry(root.desktopEntryFor(notification, item))) {
            root.setNotificationUnread(trackingId, false);
            root.removeFromPopupsById(trackingId);
            return true;
        }

        return false;
    }

    function unreadMapCount(unreadMap) {
        var count = 0;
        for (var key in unreadMap) {
            if (unreadMap[key]) {
                count++;
            }
        }
        return count;
    }

    function setNotificationUnread(trackingId, unread) {
        var next = {};
        for (var key in root.unreadNotifications) {
            if (root.unreadNotifications[key]) {
                next[key] = true;
            }
        }

        if (unread) {
            next[trackingId] = true;
        } else {
            delete next[trackingId];
        }

        root.unreadNotifications = next;
        root.unreadCount = root.unreadMapCount(next);
        schedulePersist();
    }

    function markAllAsRead() {
        root.unreadNotifications = ({});
        root.unreadCount = 0;
        schedulePersist();
    }

    function schedulePersist() {
        if (!stateReady || hydratingState)
            return;
        persistTimer.restart();
    }

    function persistState() {
        if (!stateReady || hydratingState)
            return;

        const items = [];
        for (let i = 0; i < history.count; i++) {
            const item = history.get(i);
            items.push({
                summary: item.summary || "",
                body: item.body || "",
                appIcon: item.appIcon || "",
                appName: item.appName || "",
                desktopEntry: item.desktopEntry || "",
                id: Number(item.id || 0),
                trackingId: item.trackingId || ("persisted_" + i),
                urgency: Number(item.urgency || 0),
                timeoutMs: Number(item.timeoutMs || 0),
                time: item.time || "",
                unread: Boolean(unreadNotifications[item.trackingId])
            });
        }

        persistenceFile.setText(JSON.stringify({
            version: 1,
            doNotDisturb: doNotDisturb,
            history: items
        }, null, 2) + "\n");
    }

    function restoreState(text) {
        hydratingState = true;
        try {
            const state = JSON.parse(String(text || "{}"));
            if (!state || state.version !== 1 || !(state.history instanceof Array))
                throw new Error("unsupported notification state");

            history.clear();
            unreadNotifications = ({});
            unreadCount = 0;
            const items = state.history.slice(0, maximumHistoryItems);
            for (let i = 0; i < items.length; i++) {
                const saved = items[i] || ({});
                const trackingId = saved.trackingId || ("persisted_" + Date.now() + "_" + i);
                history.append({
                    summary: saved.summary || "",
                    body: saved.body || "",
                    appIcon: saved.appIcon || "",
                    appName: saved.appName || "",
                    desktopEntry: saved.desktopEntry || "",
                    id: Number(saved.id || 0),
                    trackingId: trackingId,
                    urgency: Number(saved.urgency || 0),
                    timeoutMs: Number(saved.timeoutMs || 0),
                    time: saved.time || ""
                });
                if (saved.unread)
                    unreadNotifications[trackingId] = true;
            }
            unreadCount = unreadMapCount(unreadNotifications);
            doNotDisturb = Boolean(state.doNotDisturb);
        } catch (error) {
            console.warn("Notifications: ignoring invalid persisted state: " + error);
        }
        hydratingState = false;
    }

    function statusJson() {
        return JSON.stringify({
            doNotDisturb: doNotDisturb,
            unreadCount: unreadCount,
            historyCount: history.count,
            popupCount: popups.count,
            persistenceReady: stateReady
        });
    }

    function createServer() {
        if (server === null) {
            server = serverComponent.createObject(root);
        }
    }

    Component.onCompleted: {
        if (serverMode === "off") {
            return;
        } else if (serverMode === "on") {
            createServer();
        } else {
            ownerCheckDelay.start();
        }
    }
}
