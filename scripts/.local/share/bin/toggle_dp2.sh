#!/usr/bin/env bash
set -euo pipefail

output="DP-2"
mode="2560x1440@120"
position="0x0"
scale="1"

enable_lua_monitor() {
    hyprctl eval "hl.monitor({ output = \"${output}\", mode = \"${1}\", position = \"${2}\", scale = ${3} })"
}

disable_lua_monitor() {
    hyprctl eval "hl.monitor({ output = \"${output}\", disabled = true })"
}

enable_legacy_monitor() {
    hyprctl keyword monitor "${output}, ${1}, ${2}, ${3}"
}

disable_legacy_monitor() {
    hyprctl keyword monitor "${output}, disable"
}

enable_monitor() {
    if ! enable_lua_monitor "$@"; then
        enable_legacy_monitor "$@"
    fi
}

disable_monitor() {
    if ! disable_lua_monitor; then
        disable_legacy_monitor
    fi
}

# Check if DP-2 is currently active
if hyprctl monitors | grep -q "^Monitor ${output} "; then
    # It is active, so disable it
    disable_monitor
else
    # It is not active, so enable it using the specific config settings
    enable_monitor "${mode}" "${position}" "${scale}"
fi
