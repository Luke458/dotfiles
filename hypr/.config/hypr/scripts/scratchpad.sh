#!/usr/bin/env bash
set -euo pipefail

name="${1:?scratchpad name required}"
width="${2:?width factor required}"
height="${3:?height factor required}"
shift 3

if [ "$#" -eq 0 ]; then
    echo "scratchpad.sh: command required" >&2
    exit 2
fi

lua_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '%s' "$value"
}

workspace="special:${name}"
command="$(lua_escape "$*")"

if ! hyprctl -j workspaces | jq -e --arg workspace "$workspace" \
    'any(.[]; .name == $workspace and ((.windows // 0) > 0))' >/dev/null; then
    hyprctl dispatch "hl.dsp.workspace.toggle_special(\"$(lua_escape "$name")\")" >/dev/null
    hyprctl dispatch "hl.dsp.exec_cmd(\"${command}\", { workspace = \"${workspace}\", float = true, center = true, size = { \"monitor_w*${width}\", \"monitor_h*${height}\" } })" >/dev/null
    exit 0
fi

hyprctl dispatch "hl.dsp.workspace.toggle_special(\"$(lua_escape "$name")\")" >/dev/null
