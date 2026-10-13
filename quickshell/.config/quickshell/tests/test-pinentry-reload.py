#!/usr/bin/env python3
"""Reload an isolated Quickshell instance that owns a PinentryServer.

On reload the new tree's listener probe connects to the old server just
before the old tree is destroyed. The old server used to segfault replying
to that already-closed probe socket from its destructor.
"""
import os
from pathlib import Path
import signal
import socket
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
BUILD_QML = ROOT / "plugins" / "pinentry" / "build" / "qml"
INSTALLED_QML = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share")) / "qml"
import_path = BUILD_QML if BUILD_QML.is_dir() else INSTALLED_QML
if not (import_path / "Luke" / "Quickshell" / "Pinentry").is_dir():
    raise SystemExit("Pinentry module not built; run scripts/build-pinentry-plugin")

runtime = Path(os.environ.get("XDG_RUNTIME_DIR", tempfile.gettempdir()))
# AF_UNIX paths are limited to ~108 bytes, so keep the socket short.
socket_path = runtime / f"qs-pinentry-test-{os.getpid()}.sock"


def processes_in(directory: Path) -> list[int]:
    found = []
    for proc in Path("/proc").iterdir():
        if not proc.name.isdigit():
            continue
        try:
            if os.readlink(proc / "cwd") == str(directory):
                found.append(int(proc.name))
        except OSError:
            pass
    return found


with tempfile.TemporaryDirectory(prefix="qs-pinentry-test-") as directory:
    test = Path(directory)
    (test / "services").mkdir()
    service = (ROOT / "services" / "Pinentry.qml").read_text()
    needle = "component.createObject(root)"
    assert needle in service, "services/Pinentry.qml no longer uses " + needle
    service = service.replace(needle, 'component.createObject(root, { socketPath: "%s" })' % socket_path)
    (test / "services" / "Pinentry.qml").write_text(service)
    (test / "services" / "qmldir").write_text("singleton Pinentry Pinentry.qml\n")
    shell = test / "shell.qml"
    shell.write_text("""import QtQuick
import Quickshell
import "services"
ShellRoot {
    Component.onCompleted: console.log("pinentry-test available", Pinentry.available)
    // Answer any prompt so the client round-trip exercises reply().
    Timer {
        interval: 100; repeat: true; running: true
        onTriggered: if (Pinentry.active) Pinentry.accept()
    }
}
""")

    env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QML_IMPORT_PATH=str(import_path),
               QML2_IMPORT_PATH=str(import_path), QS_NOTIFICATION_SERVER="off")
    log = test / "quickshell.log"
    with log.open("w") as output:
        process = subprocess.Popen(["quickshell", "-p", str(shell)], cwd=test, env=env,
                                   stdout=output, stderr=subprocess.STDOUT)
    try:
        time.sleep(2)
        client = socket.socket(socket.AF_UNIX)
        client.settimeout(5)
        client.connect(str(socket_path))
        client.sendall(b'{"mode":"confirm","description":"test"}\n')
        answer = b""
        while not answer.endswith(b"\n"):
            chunk = client.recv(4096)
            if not chunk:
                break
            answer += chunk
        client.close()
        assert answer.strip() == b'{"status":"ok"}', answer
        for reload in range(2):
            with shell.open("a") as handle:
                handle.write(f"// reload {reload}\n")
            time.sleep(2.5)
        alive = process.poll() is None
    finally:
        for pid in processes_in(test):
            try:
                os.kill(pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
        socket_path.unlink(missing_ok=True)

    text = log.read_text(errors="replace")
    assert "has crashed" not in text, text[-3000:]
    assert alive, "quickshell exited during reload\n" + text[-3000:]
    assert text.count("Reloading configuration") >= 2, text[-3000:]
    assert text.count("pinentry-test available true") >= 3, text[-3000:]

print("pinentry reload test passed")
