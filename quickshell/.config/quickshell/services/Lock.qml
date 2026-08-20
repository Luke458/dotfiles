pragma Singleton

import QtQuick
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
}
