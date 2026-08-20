#!/usr/bin/env sh
set -eu

shell_root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

require_text() {
    pattern=$1
    file=$2
    if ! grep -Eq "$pattern" "$shell_root/$file"; then
        printf 'missing contract %s in %s\n' "$pattern" "$file" >&2
        exit 1
    fi
}

reject_text() {
    pattern=$1
    file=$2
    if grep -Eq "$pattern" "$shell_root/$file"; then
        printf 'obsolete contract %s remains in %s\n' "$pattern" "$file" >&2
        exit 1
    fi
}

require_text 'property bool requested' services/Lock.qml
require_text 'property bool sessionLocked' services/Lock.qml
require_text 'property bool secure' services/Lock.qml
require_text 'function statusJson' services/Lock.qml
reject_text 'Lock\.locked[[:space:]]*=' services/Power.qml
require_text 'Lock\.requestLock\(\)' services/Power.qml
require_text 'Lock\.secure' services/Power.qml
require_text 'Power\.suspend\(\)' components/PickerOverlay.qml
require_text 'Power\.displayOff\(\)' components/PickerOverlay.qml
require_text 'interval: 1000' services/Power.qml
require_text 'Hyprland\.usingLua' services/Power.qml
require_text 'hl\.dsp\.dpms\(\{ action = \\"disable\\" \}\)' services/Power.qml
require_text ': "dpms off"' services/Power.qml
require_text 'menuEntry: modelData \|\| null' components/TrayMenu.qml
require_text 'property list<Component> expandableModules' windows/Bar.qml
require_text 'property bool leftSectionExpanded: true' shell.qml
require_text 'LazyLoader' shell.qml
require_text 'background: Item \{\}' components/PickerOverlay.qml
require_text 'atomicWrites: true' services/Notifications.qml
require_text 'version: 1' services/Notifications.qml
require_text 'kill -0' scripts/restart-shell
require_text 'ipc call lock lock' scripts/lock-before-sleep
require_text 'AddressInUseError' plugins/pinentry/src/pinentryserver.cpp
require_text 'waitForConnected' plugins/pinentry/src/pinentryserver.cpp
require_text 'QFileInfo::exists\(mSocketPath\)' plugins/pinentry/src/pinentryserver.cpp
reject_text 'launcherLease|barLeaseActive|instanceCheck' launcher.qml
reject_text 'launcherLease|barLeaseActive|instanceCheck' pass.qml
reject_text 'launcherLease|barLeaseActive|instanceCheck' power.qml

if [ ! -x "$shell_root/scripts/lock-before-sleep" ]; then
    printf '%s\n' 'scripts/lock-before-sleep must be executable' >&2
    exit 1
fi

printf '%s\n' 'shell contract tests passed'
