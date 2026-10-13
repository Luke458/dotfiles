#!/usr/bin/env bash
#
# Run the Quickshell test suite.
#
# The tests here are self-contained: the lock/sleep/restart tests replace the
# real helpers with stubs, and the QML tests use an offscreen Qt platform, so
# they do not lock, suspend, or restart the running session. Tests whose
# prerequisites (qs, node, a built pinentry plugin) are missing are skipped.

set -uo pipefail

here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$here" || exit 1

failures=0
ran=0

have() { command -v "$1" >/dev/null 2>&1; }

pass() {
  ran=$((ran + 1))
  printf 'ok: %s\n' "$1"
}

fail() {
  failures=$((failures + 1))
  printf 'FAILED: %s\n' "$1" >&2
}

skip() { printf 'skip: %s (%s)\n' "$1" "$2"; }

run() {
  local name=$1
  shift
  printf '\n==> %s\n' "$name"
  if "$@"; then
    pass "$name"
  else
    fail "$name"
  fi
}

run shell-contracts sh ./test-shell-contracts.sh

if have node; then
  run picker-model node ./test-picker-model.mjs
else
  skip picker-model "node not found"
fi

if have python3; then
  run update-monitor python3 ./test_update_monitor.py
else
  skip update-monitor "python3 not found"
fi

if have qs; then
  run design python3 ./test-design.py
  run lock-before-sleep python3 ./test-lock-before-sleep.py
  run restart-safety python3 ./test-restart-safety.py
  run service-regressions python3 ./test-service-regressions.py
  if [ -d ../plugins/pinentry/build/qml ] ||
    [ -d "${XDG_DATA_HOME:-$HOME/.local/share}/qml/Luke/Quickshell/Pinentry" ]; then
    run pinentry-reload python3 ./test-pinentry-reload.py
  else
    skip pinentry-reload "pinentry module not built"
  fi
else
  skip qml-suite "qs not found"
fi

printf '\n----------------------------------------\n'
printf 'ran %d test(s), %d failure(s)\n' "$ran" "$failures"
((failures == 0))
