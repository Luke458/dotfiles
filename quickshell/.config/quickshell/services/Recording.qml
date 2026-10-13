pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Webcam and screen recording control. Screen capture uses gpu-screen-recorder
// (stopped over its IPC socket via gsr-cli, which returns the saved path);
// webcam capture runs ffmpeg headless and stops with SIGINT so the container is
// finalized. Both survive a shell restart: state is rediscovered on load.
QtObject {
    id: root

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string outputDir: (Quickshell.env("XDG_VIDEOS_DIR") || home + "/Videos") + "/Recordings"
    readonly property string screenSocket: runtimeDir + "/qs-screen-record.sock"
    readonly property string webcamPidFile: runtimeDir + "/qs-webcam-record.pid"
    readonly property string webcamDevice: Quickshell.env("WEBCAM_DEVICE")
        || "/dev/v4l/by-id/usb-UGREEN_UGREEN_AI_Camera_CM930_4K_2025102215-video-index0"
    readonly property string webcamAudio: Quickshell.env("WEBCAM_AUDIO_SOURCE")
        || "alsa_input.usb-UGREEN_UGREEN_AI_Camera_CM930_4K_2025102215-02.mono-fallback"

    property bool screenActive: false
    property bool webcamActive: false
    property double screenStartedAt: 0
    property double webcamStartedAt: 0
    property string screenOutputPath: ""
    property string webcamOutputPath: ""
    property string lastSaved: ""
    property string errorMessage: ""
    property bool desktopAudio: true
    property bool micAudio: false

    property bool screenStopping: false
    property bool webcamStopping: false

    readonly property bool anyActive: screenActive || webcamActive
    // Only short-lived start/stop transitions count as busy. The recorder
    // processes themselves run for the whole recording, so including them here
    // would disable the Stop button (and the other recorder's Start) while a
    // recording was running.
    readonly property bool busy: screenStopProc.running || webcamStopProc.running
        || webcamDeviceCheck.running

    function timestamp() {
        const date = new Date();
        const pad = value => String(value).padStart(2, "0");
        return date.getFullYear() + "-" + pad(date.getMonth() + 1) + "-" + pad(date.getDate())
            + "_" + pad(date.getHours()) + "-" + pad(date.getMinutes()) + "-" + pad(date.getSeconds());
    }

    function elapsedSec(startedAt) {
        return startedAt > 0 ? Math.max(0, Math.floor((Date.now() - startedAt) / 1000)) : 0;
    }

    function formatElapsed(seconds) {
        const total = Math.max(0, Math.floor(Number(seconds) || 0));
        const pad = value => String(value).padStart(2, "0");
        const hours = Math.floor(total / 3600);
        const minutes = Math.floor((total % 3600) / 60);
        const secs = total % 60;
        return hours > 0 ? hours + ":" + pad(minutes) + ":" + pad(secs) : pad(minutes) + ":" + pad(secs);
    }

    // ------------------------------------------------------------- screen
    function startScreen() {
        if (screenActive) return;
        screenStopping = false;
        const monitor = Hyprland.focusedMonitor && Hyprland.focusedMonitor.name
            ? String(Hyprland.focusedMonitor.name) : "";
        if (monitor === "") {
            errorMessage = "No focused monitor to record";
            return;
        }
        errorMessage = "";
        const out = outputDir + "/screen-" + timestamp() + ".mp4";
        screenOutputPath = out;
        const args = ["-w", monitor, "-f", "60", "-c", "mp4", "-k", "h264", "-ipc", screenSocket, "-o", out];
        if (desktopAudio) args.push("-a", "default_output");
        if (micAudio) args.push("-a", "default_input");
        screenProc.command = ["sh", "-c", 'mkdir -p -- "$1" && shift && exec gpu-screen-recorder "$@"', "screen-rec", outputDir].concat(args);
        screenProc.running = true;
        screenActive = true;
        screenStartedAt = Date.now();
    }

    function stopScreen() {
        if (!screenActive || screenStopProc.running) return;
        screenStopping = true;
        screenStopProc.running = true;
    }

    function toggleScreen() {
        if (screenActive) stopScreen();
        else startScreen();
    }

    // ------------------------------------------------------------- webcam
    function startWebcam() {
        if (webcamActive || webcamDeviceCheck.running) return;
        errorMessage = "";
        webcamDeviceCheck.command = ["test", "-e", webcamDevice];
        webcamDeviceCheck.running = true;
    }

    function launchWebcam() {
        webcamStopping = false;
        const out = outputDir + "/webcam-" + timestamp() + ".mkv";
        webcamOutputPath = out;
        const args = [
            "-nostdin", "-hide_banner", "-loglevel", "warning",
            "-f", "v4l2", "-input_format", "mjpeg", "-video_size", "1920x1080", "-framerate", "30", "-i", webcamDevice,
            "-f", "pulse", "-i", webcamAudio,
            "-map", "0:v:0", "-map", "1:a:0", "-c:v", "copy", "-c:a", "flac",
            out
        ];
        webcamProc.command = ["sh", "-c",
            'mkdir -p -- "$1" && pid="$2" && shift 2 && echo $$ > "$pid" && exec ffmpeg "$@"',
            "webcam-rec", outputDir, webcamPidFile].concat(args);
        webcamProc.running = true;
        webcamActive = true;
        webcamStartedAt = Date.now();
    }

    function stopWebcam() {
        if (!webcamActive || webcamStopProc.running) return;
        webcamStopping = true;
        webcamStopProc.running = true;
    }

    function toggleWebcam() {
        if (webcamActive) stopWebcam();
        else startWebcam();
    }

    function toggle() {
        if (anyActive) {
            if (screenActive) stopScreen();
            if (webcamActive) stopWebcam();
        } else {
            startScreen();
        }
    }

    function statusJson() {
        return JSON.stringify({
            screen: screenActive,
            webcam: webcamActive,
            screenPath: screenOutputPath,
            webcamPath: webcamOutputPath,
            lastSaved: lastSaved,
            busy: busy,
            error: errorMessage
        });
    }

    // ------------------------------------------------------------- processes
    property Process screenProc: Process {
        running: false
        onExited: exitCode => {
            const expected = root.screenStopping;
            root.screenStopping = false;
            root.screenActive = false;
            root.screenStartedAt = 0;
            if (!expected && exitCode !== 0 && root.errorMessage === "")
                root.errorMessage = "Screen recorder exited (" + exitCode + ")";
        }
    }

    property Process screenStopProc: Process {
        command: ["gsr-cli", "-ipc", root.screenSocket, "stop"]
        running: false
        stdout: SplitParser {
            onRead: line => {
                const value = String(line || "").trim();
                if (value !== "") root.lastSaved = value;
            }
        }
        onExited: exitCode => {
            root.screenActive = false;
            root.screenStartedAt = 0;
            if (exitCode !== 0)
                root.errorMessage = "Could not stop the screen recorder";
        }
    }

    property Process screenStatusProc: Process {
        command: ["gsr-cli", "-ipc", root.screenSocket, "status"]
        running: false
        onExited: exitCode => {
            if (exitCode === 0 && !root.screenActive) {
                root.screenActive = true;
                root.screenStartedAt = Date.now();
            }
        }
    }

    property Process webcamProc: Process {
        running: false
        onExited: exitCode => {
            const expected = root.webcamStopping;
            root.webcamStopping = false;
            root.webcamActive = false;
            root.webcamStartedAt = 0;
            if (!expected && exitCode !== 0 && root.errorMessage === "")
                root.errorMessage = "Webcam recorder exited (" + exitCode + ")";
        }
    }

    property Process webcamDeviceCheck: Process {
        command: []
        running: false
        onExited: exitCode => {
            if (exitCode === 0)
                root.launchWebcam();
            else
                root.errorMessage = "Webcam is not available: " + root.webcamDevice;
        }
    }

    property Process webcamStopProc: Process {
        command: ["sh", "-c",
            'pidfile="$1"; [ -f "$pidfile" ] && kill -INT "$(cat "$pidfile")" 2>/dev/null; true',
            "webcam-stop", root.webcamPidFile]
        running: false
    }

    property Process webcamStatusProc: Process {
        command: ["sh", "-c",
            'pidfile="$1"; [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null',
            "webcam-status", root.webcamPidFile]
        running: false
        onExited: exitCode => {
            if (exitCode === 0 && !root.webcamActive) {
                root.webcamActive = true;
                root.webcamStartedAt = Date.now();
            }
        }
    }

    Component.onCompleted: {
        screenStatusProc.running = true;
        webcamStatusProc.running = true;
    }
}
