pragma Singleton

import QtQuick
import Quickshell.Io
import Quickshell.Services.Pam

QtObject {
    id: root

    property bool requested: false
    property bool pending: false
    property bool sessionLocked: false
    property bool secure: false
    readonly property bool locked: requested || pending || sessionLocked || secure
    property bool authInProgress: false
    property bool authFailed: false
    property string pendingPassword: ""

    onSessionLockedChanged: {
        if (!sessionLocked && !secure && !requested) {
            pendingPassword = "";
            authInProgress = false;
            authFailed = false;
        }
    }

    function requestLock(): bool {
        if (locked)
            return true;
        pendingPassword = "";
        authInProgress = false;
        authFailed = false;
        pending = true;
        requested = true;
        return true;
    }

    function cancelRequest(): bool {
        // Withdraw a lock request that was never confirmed by the compositor
        // (e.g. denied or raced). A live session lock must be unlocked
        // normally; killing the shell while it owns WlSessionLock would leave
        // conformant compositors locked.
        if (sessionLocked || secure)
            return false;
        requested = false;
        pending = false;
        authInProgress = false;
        authFailed = false;
        pendingPassword = "";
        return true;
    }

    function updateSessionState(isLocked: bool, isSecure: bool): void {
        sessionLocked = isLocked;
        secure = isSecure;
        if (isLocked || isSecure)
            pending = false;
        if (!isLocked && !isSecure && !requested)
            pending = false;
    }

    function statusJson(): string {
        return JSON.stringify({
            requested: requested,
            pending: pending,
            sessionLocked: sessionLocked,
            secure: secure,
            locked: locked,
            authInProgress: authInProgress
        });
    }

    function clearFailure(): void {
        authFailed = false;
    }

    function tryUnlock(password: string): bool {
        if (password.length === 0 || authInProgress)
            return false;

        pendingPassword = password;
        authInProgress = true;
        authFailed = false;
        if (!pam.start()) {
            finishAuthentication(false);
            return false;
        }

        return true;
    }

    function finishAuthentication(success: bool): void {
        pendingPassword = "";
        authInProgress = false;
        authFailed = !success;
        if (success) {
            requested = false;
            pending = false;
        }
    }

    property PamContext pam: PamContext {
        configDirectory: "pam"
        config: "quickshell"

        onPamMessage: {
            if (responseRequired)
                respond(root.pendingPassword);
        }

        onCompleted: result => root.finishAuthentication(result === PamResult.Success)
    }

    // --- Stranded-lock recovery -------------------------------------------------
    // An ext-session-lock outlives its client: if the compositor still reports
    // an active session lock but this shell holds none (the previous locker
    // crashed or was killed), re-acquire the lock so the unlock surface is
    // available instead of sitting behind the compositor's failsafe.
    function recoverStrandedLock() {
        if (sessionLocked || secure || requested || pending)
            return;
        console.warn("Lock: session is locked but no locker owns it; re-acquiring");
        requested = true;
    }

    property Process strandedLockCheck: Process {
        command: ["sh", "-c",
            "hyprctl -j monitors 2>/dev/null | jq -r 'if any(.[]; (.solitaryBlockedBy // []) | index(\"LOCK\")) then \"locked\" else \"unlocked\" end'"]
        stdout: SplitParser {
            onRead: data => {
                if (data.trim() === "locked")
                    root.recoverStrandedLock();
            }
        }
    }

    property Timer strandedCheckTimer: Timer {
        interval: 1500
        running: true
        repeat: false
        onTriggered: root.strandedLockCheck.running = true
    }
}
