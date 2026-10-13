# Quickshell improvements — 8 September 2026

## Implemented reliability fixes

- Restart refuses failed, incomplete or malformed lock status and queries each selected PID explicitly before stopping it.
- Notification eviction closes the underlying server object. Expiration continues when a toast is hidden or DND suppresses it. History retains snapshots, and clearing all includes transient notifications.
- Network heading, address and disconnect action consistently prefer the connected wired device, falling back to Wi-Fi.
- Wi-Fi scanning follows device replacement through a binding and stops when the final details consumer closes.
- Shutdown, reboot, suspend and logout report failed exits, crashes and missing executables.
- Media position refresh runs only while a details view observes playback.
- Weather rejects blank, nonnumeric and out-of-range coordinates. Correction to the initial review: coordinates are strings, so the old code already accepted "0".
- Removed the four unused imports identified by lint.

## Repository-backed feature shortlist

These are proposals, not enabled features. Sources are the local skill knowledge checkouts, not a claim about current upstream releases. Inspected snapshots: DMS `8d9c9616` (13 August), end-4 `69f1a543` (11 August), Yet Another Quickshell `5f14e35` (7 August), all 2026.

### 1. Notification action buttons — best small next change

**Benefit:** expose actions supplied by applications directly in the card instead of only attempting default activation.

**Reference:** [DMS notification cards](/home/luke/Projects/quickshell-knowledge/dms/quickshell/Modules/Notifications/Center/NotificationCard.qml:925) render action labels, invoke the selected action and offer numbered keyboard hints.

**Local fit:** extend `components/NotificationCard.qml` and the existing `services/Notifications.qml`. The local server currently advertises `actionsSupported: false`. Enable that only once live actions are rendered correctly. Show actions only while the notification object is live; persisted snapshots must not imply that an action can still run. Respect resident notifications when invoking actions. Inline replies are a separate feature with additional lifecycle work.

**Dependencies:** installed Quickshell notification API; no new daemon. Verify action invocation and notification close reasons against the installed revision, with an application-generated test notification.

### 2. Clipboard history inside the existing picker

**Benefit:** search and recopy recent text and images using the same keyboard navigation and focused-monitor placement as the launcher and emoji picker.

**References:** [Yet Another Quickshell clipboard service](/home/luke/Projects/quickshell-knowledge/yet-another-quickshell/services/Clipboard.qml) uses `cliphist` and image previews. [DMS clipboard service](/home/luke/Projects/quickshell-knowledge/dms/quickshell/Services/ClipboardService.qml:19) separates pinned entries, search and selection state.

**Local fit:** add a `clipboard` mode to `OverlayController` and `PickerOverlay`, backed by one service. Load a bounded list on opening and decode a selected image on demand. Provide per-entry deletion, clear history and an explicit history-pause control.

**Dependencies and limits:** `wl-copy` and `wl-paste` are installed; `cliphist` was not found on PATH. This would introduce clipboard persistence and a supervised watcher. DMS delegates its operations to its own daemon, while the YAQ file uses project-specific `Globals`, `Preferences` and `ProcessService`, including a hard-coded home path. Reuse the design, not either service verbatim. Default to copying a selection; automatic paste needs a separate focused-window/compositor check.

### 3. Bluetooth indicator and device flyout

**Benefit:** connect saved headphones/devices, see battery levels and diagnose connection progress without opening an external manager.

**References:** [DMS Bluetooth service](/home/luke/Projects/quickshell-knowledge/dms/quickshell/Services/BluetoothService.qml:14) derives availability, connection state and device battery data. [YAQ Bluetooth service](/home/luke/Projects/quickshell-knowledge/yet-another-quickshell/services/Bluetooth.qml) is a smaller adapter/device example.

**Local fit:** a singleton plus expandable-bar indicator and lazy details panel, matching Network and Waydroid. Begin with saved-device connect/disconnect, adapter power and battery. Scan only while the panel is open and explicitly requested; show asynchronous failures.

**Dependencies and limits:** `bluetoothctl` is installed. Actual adapter availability, installed native API coverage and pairing-agent ownership still need live verification. DMS enhanced pairing and codec controls depend on its daemon/DBus bridge and optional scripts; they are not portable QML features. New-device pairing should be a separately validated step.

### 4. Capture menu and recording status

**Benefit:** unify region/output screenshots with a visible recording timer and stop control in the bar.

**Reference:** [end-4 screenshot actions](/home/luke/Projects/quickshell-knowledge/end-4/dots/.config/quickshell/ii/modules/common/utils/ScreenshotAction.qml) offers copy, annotate, OCR and record actions from a region selection.

**Local fit:** extend existing Print/Shift+Print screenshot workflows (`hyprshot`) with a small capture picker. Use the existing OSD for start/stop feedback and one indicator only while a recording is active.

**Dependencies and limits:** `hyprshot`, `slurp` and `gpu-screen-recorder` are installed; `satty` was not found on PATH. Recording must own a unique process/service and survive shell reloads, with SIGINT finalization. Codec, audio and output validation require a real short recording. end-4's helpers depend on its Config/Directories/StringUtils services; its upload/image-search actions are not part of this proposal.

## Validation

- All 88 QML files lint cleanly with the Pinentry plugin import paths.
- Existing shell contract checks pass.
- `python tests/test-restart-safety.py`: eight mocked cases, with no real process killed.
- `python tests/test-service-regressions.py`: isolated windowless service harness tests server-object eviction, transient cleanup, DND and hidden-toast expiration, snapshot preservation, scanner replacement, device selection, and power denial/missing-executable notifications. No real network changes or power operations occur.
- Media visibility gating is wired into details-view lifetime; graphical seek/visibility behavior still merits an interactive check with an active player.
- Live shell: a transient `notify-send --wait` notification expired within the bounded check; lock IPC returned all lock flags false after reload.
