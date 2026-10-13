#!/usr/bin/env python3
"""Exercise restart safety without issuing real IPC, kill or UWSM commands."""
import json
import os
from pathlib import Path
import subprocess
import tempfile


def check(condition, detail):
    # Deliberately not `assert`: CPython strips assert statements under -O, so
    # an optimized run would report success having verified nothing.
    if not condition:
        raise SystemExit(f"FAILED: {detail}")


ROOT = Path(__file__).resolve().parents[1]
FLAGS = ('locked', 'requested', 'pending', 'sessionLocked', 'secure')
unlocked = {key: False for key in FLAGS}
locked = dict(unlocked, locked=True, sessionLocked=True)

QS_STUB = '''#!/bin/sh
case "$1" in
list)
  if [ -e "$TEST_LIST_SEEN" ]; then
    printf '%s\\n' "$TEST_INSTANCES_AFTER"
  else
    : > "$TEST_LIST_SEEN"
    printf '%s\\n' "$TEST_INSTANCES"
  fi
  exit "$TEST_LIST_EXIT";;
ipc)
  printf '%s\\n' "$*" >> "$TEST_IPC"
  if [ -n "$TEST_LOCKED_PID" ]; then
    case "$*" in
      *"--pid $TEST_LOCKED_PID "*) printf '%s\\n' "$TEST_LOCKED_STATUS"; exit "$TEST_LOCKED_EXIT";;
    esac
  fi
  printf '%s\\n' "$TEST_STATUS"; exit "$TEST_IPC_EXIT";;
kill) printf '%s\\n' "$*" >> "$TEST_KILLS";;
esac
'''

UWSM_STUB = '''#!/bin/sh
printf '%s\\n' "$*" >> "$TEST_UWSM_LOG"
exit "$TEST_UWSM_EXIT"
'''


def drive(restart, scripts, root, instances, instances_after=None, status=None,
          ipc_exit=0, list_exit=0, locked_pid="", locked_status=None, locked_exit=0,
          uwsm_exit=99, timeout=10):
    """Run restart-shell against the stubs and report what it actually did."""
    kills, ipc_log, uwsm_log, list_seen = (root / name for name in
                                           ('kills', 'ipc', 'uwsm-log', 'list-seen'))
    for path in (kills, ipc_log, uwsm_log, list_seen):
        path.unlink(missing_ok=True)
    env = dict(os.environ,
               PATH=str(scripts) + ':' + os.environ['PATH'],
               TEST_INSTANCES=json.dumps(instances),
               TEST_INSTANCES_AFTER=json.dumps(instances if instances_after is None else instances_after),
               TEST_STATUS=json.dumps(unlocked) if status is None else status,
               TEST_IPC_EXIT=str(ipc_exit),
               TEST_LIST_EXIT=str(list_exit),
               TEST_LOCKED_PID=str(locked_pid),
               TEST_LOCKED_STATUS=json.dumps(unlocked) if locked_status is None else locked_status,
               TEST_LOCKED_EXIT=str(locked_exit),
               TEST_UWSM_EXIT=str(uwsm_exit),
               TEST_KILLS=str(kills),
               TEST_IPC=str(ipc_log),
               TEST_UWSM_LOG=str(uwsm_log),
               TEST_LIST_SEEN=str(list_seen))
    result = subprocess.run([str(restart)], env=env, capture_output=True, text=True, timeout=timeout)
    return (result.returncode,
            kills.read_text() if kills.exists() else '',
            uwsm_log.read_text() if uwsm_log.exists() else '',
            ipc_log.read_text() if ipc_log.exists() else '')


with tempfile.TemporaryDirectory(prefix="qs-restart-test-") as directory:
    root = Path(directory)
    scripts = root / "scripts"
    scripts.mkdir()
    restart = scripts / "restart-shell"
    restart.write_text((ROOT / "scripts/restart-shell").read_text())
    restart.chmod(0o755)
    stub = scripts / "qs"
    stub.write_text(QS_STUB)
    stub.chmod(0o755)
    uwsm = scripts / "uwsm"
    uwsm.write_text(UWSM_STUB)
    uwsm.chmod(0o755)

    mine = str(root / 'shell.qml')
    other = str(root / 'elsewhere' / 'shell.qml')
    running = [dict(config_path=mine, pid=99999999)]

    # Lock-state gate. A kill is expected only for a fully unlocked instance, and
    # reaching the launch step is observable as the uwsm stub being called.
    gate = [('unlocked', json.dumps(unlocked), 0, 0, True),
            ('IPC failed', '', 1, 0, False),
            ('empty', '', 0, 0, False),
            ('malformed', '{', 0, 0, False),
            ('missing fields', '{}', 0, 0, False),
            ('wrong types', json.dumps(dict(unlocked, secure='false')), 0, 0, False),
            ('secure', json.dumps(dict(unlocked, secure=True)), 0, 0, False),
            ('list failed', json.dumps(unlocked), 0, 1, False)]
    for name, status, ipc_exit, list_exit, expect_kill in gate:
        code, kills, launched, _ = drive(restart, scripts, root, running,
                                         status=status, ipc_exit=ipc_exit, list_exit=list_exit)
        check((kills != '') == expect_kill, (name, code, kills))
        check(code == (99 if expect_kill else 75), (name, code))
        check(bool(launched) == expect_kill, (name, 'uwsm', launched))

    # No instance at all is a normal start, not a refusal.
    code, kills, launched, _ = drive(restart, scripts, root, [], instances_after=running,
                                     status=json.dumps(unlocked), uwsm_exit=0)
    check(kills == '', ('empty list must not kill anything', kills))
    check('luke-quickshell' in launched, ('empty list must launch the shell', launched))
    check(code == 0, ('empty list should restart cleanly', code))

    # Instances exist but none is this config: refuse rather than risk a second bar.
    code, kills, launched, _ = drive(restart, scripts, root, [dict(config_path=other, pid=1234)])
    check(kills == '', ('path mismatch must not kill anything', kills))
    check(launched == '', ('path mismatch must not launch a second shell', launched))
    check(code == 75, ('path mismatch should refuse', code))

    # A locked instance anywhere in the set must block the whole restart, so no
    # already-validated sibling is stopped first.
    pair = [dict(config_path=mine, pid=111), dict(config_path=mine, pid=222)]
    code, kills, launched, _ = drive(restart, scripts, root, pair, status=json.dumps(unlocked),
                                     locked_pid=222, locked_status=json.dumps(locked))
    check(kills == '', ('a locked sibling must stop every kill', kills))
    check(launched == '', ('a locked sibling must stop the launch', launched))
    check(code == 75, ('a locked sibling should refuse', code))

    code, _, _, ipc_log = drive(restart, scripts, root, running, status=json.dumps(unlocked))
    check('ipc --pid 99999999 call lock status' in ipc_log,
          'restart-shell must query the lock status of each selected pid')

    print(f'{len(gate) + 4} restart safety cases passed')
