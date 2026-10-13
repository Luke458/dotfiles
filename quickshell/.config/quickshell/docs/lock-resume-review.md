# Lock and resume review — 27 September 2026

## Incident evidence

Previous boot `88f7b3e275d74e5aadbf3db5e86463c3` suspended at 02:24:14.
At 11:11:44, Linux returned from suspend and thawed the user slice. The kernel
reported AMD GPU illegal opcodes, page faults and graphics-ring timeouts for
both Quickshell (619607) and Hyprland (619488). Quickshell reported a lost GPU
context and exited with status 134. Restart attempts encountered a refused
Wayland connection. The user saw Hyprland's lock recovery screen.

This establishes a graphics/session failure, not a password rejection. It does
not establish whether a rendering change, driver, compositor, or hardware
triggered the fault. Another GPU timeout occurred at 23:45 the previous evening.
No driver configuration or rendering backend has been changed in this review.

## Corrections

- Hypridle now explicitly uses `general:inhibit_sleep = 3`. Its default auto
  detection recognizes hyprlock, not this Quickshell hook, and otherwise releases
  the delay inhibitor after spawning the command. Mode 3 waits for the compositor
  lock notification. Installed hypridle 0.1.8 supports it; the live replacement
  process confirmed the lock-notify protocol and acquired its sleep inhibitor.
- `WlSessionLock.locked` follows `Lock.requested`, independent of output count.
  Temporary removal of all outputs must not request an unlock. Quickshell owns
  the lock surfaces and handles screen changes. Local core source supports this;
  its revision differs from the installed binary, so physical hotplug remains
  untested.
- The hook requires a successful IPC exit and exactly one JSON object whose
  `secure` field is boolean true. It no longer accepts a substring in malformed
  output or output from a failed command.
- The deferred paired read of `locked` and `secure` is retained. It prevents an
  intermediate unlock notification from leaving stale service state.

A delay inhibitor has a logind deadline; it is not an unlimited veto. Hook exit
status alone never guaranteed cancellation. The shell power action separately
refuses to issue suspend until its lock is secure.

## Validation and limits

98 QML files lint cleanly; 10 hook cases pass, including malformed JSON, nested
fields, string booleans, multiple JSON values, and failed IPC. Design, service and
shell-contract regressions pass. The live shell reloaded and was explicitly
unlocked before editing. Hypridle was restarted independently of Quickshell.
Subsequent live logs recorded successful PAM authentication at 11:45:22; IPC
confirmed every lock-state flag false afterward. No live suspend, GPU reset,
lock-client crash, or physical output removal was
induced. A successful real suspend/resume remains necessary before calling the
reported failure resolved. Existing startup stranded-lock recovery cannot repair
a compositor connection or GPU context that has failed.

Reference: https://wiki.hypr.land/Hypr-Ecosystem/hypridle/
