#!/usr/bin/env python3
"""Drive the sleep hook's secure / not-secure branches with fake helper binaries.

The hook reports compositor confirmation; hypridle inhibit_sleep=3 owns the
actual delay inhibitor. A hook failure does not veto logind suspend. Helpers
are mocked so these tests never lock or suspend the real session.
"""
import os
from pathlib import Path
import subprocess
import tempfile


def check(condition, detail):
    # Deliberately not `assert`: CPython strips assert statements under -O, so
    # an optimized run would report success having verified nothing.
    if not condition:
        raise SystemExit(f"FAILED: {detail}")


QS_STUB = r'''#!/bin/sh
n=$(cat "$QS_COUNT" 2>/dev/null || echo 0)
n=$((n + 1))
printf '%s' "$n" > "$QS_COUNT"
printf '%s\n' "$*" >> "$QS_LOG"
case "$*" in
  *"call lock lock"*)
    printf '%s' "$LOCK_REPLY"; exit "$LOCK_EXIT";;
  *"call lock status"*)
    if [ "$SECURE_AFTER" -gt 0 ] && [ "$n" -ge "$SECURE_AFTER" ]; then
      printf '{"secure":true}'
    else
      printf '%s' "$STATUS_REPLY"
    fi
    exit "$STATUS_EXIT";;
esac
exit 0
'''

# timeout(1) is only ever used as "timeout <duration> <cmd> ...", so dropping
# the duration argument is enough to make it a transparent exec wrapper.
TIMEOUT_STUB = '''#!/bin/sh
shift
exec "$@"
'''

# lock-before-sleep loops until the *fake* clock passes the deadline, so a
# counter that only advances when asked is what stops it spinning forever.
DATE_STUB = '''#!/bin/sh
n=$(cat "$DATE_COUNT" 2>/dev/null || echo 0)
n=$((n + 100))
printf '%s' "$n" > "$DATE_COUNT"
printf '%s' "$n"
'''

SLEEP_STUB = '#!/bin/sh\nexit 0\n'
LOGGER_STUB = '''#!/bin/sh
printf '%s\n' "$*" >> "$LOG_FILE"
exit 0
'''


def run(script, bin_dir, work, *, status_reply='{"secure":false}', status_exit=0,
        lock_reply='', lock_exit=0, secure_after=0, budget=600):
    for name in ('qs-count', 'date-count', 'log', 'qs-log'):
        (work / name).unlink(missing_ok=True)
    env = dict(os.environ,
               QS_BIN=str(bin_dir / 'qs'), TIMEOUT_BIN=str(bin_dir / 'timeout'),
               SLEEP_BIN=str(bin_dir / 'sleep'), DATE_BIN=str(bin_dir / 'date'),
               LOGGER_BIN=str(bin_dir / 'logger'), LOCK_BUDGET_MS=str(budget),
               QS_COUNT=str(work / 'qs-count'), DATE_COUNT=str(work / 'date-count'),
               LOG_FILE=str(work / 'log'), QS_LOG=str(work / 'qs-log'),
               LOCK_REPLY=lock_reply, LOCK_EXIT=str(lock_exit),
               STATUS_REPLY=status_reply, STATUS_EXIT=str(status_exit),
               SECURE_AFTER=str(secure_after))
    result = subprocess.run(['bash', str(script)], env=env, capture_output=True,
                            text=True, timeout=30)
    log = (work / 'log').read_text() if (work / 'log').exists() else ''
    qs_log = (work / 'qs-log').read_text() if (work / 'qs-log').exists() else ''
    return result.returncode, log, qs_log


with tempfile.TemporaryDirectory(prefix="qs-locksleep-test-") as directory:
    work = Path(directory)
    bin_dir = work / 'bin'
    bin_dir.mkdir()
    for name, body in (('qs', QS_STUB), ('timeout', TIMEOUT_STUB), ('date', DATE_STUB),
                       ('sleep', SLEEP_STUB), ('logger', LOGGER_STUB)):
        stub = bin_dir / name
        stub.write_text(body)
        stub.chmod(0o755)
    script = work / 'lock-before-sleep'
    script.write_text((Path(__file__).resolve().parents[1] / 'scripts/lock-before-sleep').read_text())
    script.chmod(0o755)

    # A confirmed secure lock releases logind immediately and says nothing.
    code, log, qs_log = run(script, bin_dir, work, status_reply='{"secure":true}')
    check(code == 0, ('secure lock must release the delay lock', code, log))
    check(log == '', ('a secure lock must not be logged as a failure', log))
    check('ipc call lock lock' in qs_log, ('the lock must be requested before polling', qs_log))

    # Polling continues until the compositor actually confirms.
    code, log, qs_log = run(script, bin_dir, work, secure_after=4)
    check(code == 0, ('a lock that becomes secure must release', code, log))
    check(log == '', ('becoming secure must not be logged as a failure', log))
    check(qs_log.count('call lock status') > 1, ('must poll more than once', qs_log))

    # Never confirmed: report failure; the caller owns inhibition policy.
    code, log, _ = run(script, bin_dir, work)
    check(code == 1, ('an unconfirmed lock must report failure', code))
    check('did not become secure' in log, ('the refusal must be logged', log))

    # A status payload with no secure field is not a confirmation.
    code, log, _ = run(script, bin_dir, work, status_reply='{}')
    check(code == 1, ('a status without secure must not release', code))
    check('did not become secure' in log, ('missing secure must be logged', log))

    # No reachable shell: the hook must still refuse rather than claim success.
    code, log, _ = run(script, bin_dir, work, lock_exit=1, status_exit=1, status_reply='')
    check(code == 1, ('an unreachable shell must not release the delay lock', code))
    check(log != '', ('an unreachable shell must be logged', log))

    for reply, status in [
        ('prefix {"secure":true}', 0),
        ('{"secure":true}', 1),
        ('{"secure":"true"}', 0),
        ('{"nested":{"secure":true}}', 0),
        ('{"secure":true} {}', 0),
    ]:
        code, log, _ = run(script, bin_dir, work, status_reply=reply, status_exit=status)
        check(code == 1, ('invalid or failed status must not confirm a lock', reply, status))

    print('10 lock-before-sleep cases passed')
