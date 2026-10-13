#!/usr/bin/env python3
import importlib.machinery
import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "update-monitor"
loader = importlib.machinery.SourceFileLoader("update_monitor", str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
monitor = importlib.util.module_from_spec(spec)
loader.exec_module(monitor)


class UpdateMonitorTests(unittest.TestCase):
    def test_old_flatpak_cache_is_removed(self):
        with tempfile.TemporaryDirectory() as directory:
            with mock.patch.object(monitor, "STATE", Path(directory) / "updates.json"):
                data = monitor.empty()
                data["sources"]["flatpak"] = {"items": [{"name": "old-app"}]}
                monitor.save(data)
                self.assertEqual(set(monitor.cached()["sources"]), {"packages", "aur", "mise"})

    def test_malformed_package_output_is_an_error(self):
        with self.assertRaisesRegex(RuntimeError, "Unrecognized update row"):
            monitor.package_items("unexpected server response", "aur")

    def test_aur_row_resolves_upstream_url(self):
        with mock.patch.object(monitor, "details", return_value={"llama.cpp-git": "https://github.com/ggml-org/llama.cpp"}):
            rows = monitor.package_items("llama.cpp-git old -> latest-commit\n", "aur")
        self.assertEqual(rows[0]["url"], "https://github.com/ggml-org/llama.cpp")
        self.assertEqual(rows[0]["latest"], "latest-commit")

    def test_failed_check_retains_previous_items_and_marks_error(self):
        with tempfile.TemporaryDirectory() as directory:
            with mock.patch.object(monitor, "STATE", Path(directory) / "updates.json"):
                before = monitor.empty()
                before["sources"]["aur"] = {"items": [{"name": "existing"}], "checkedAt": 12, "error": ""}
                monitor.save(before)
                with mock.patch.object(monitor, "check_packages", return_value=[]), \
                     mock.patch.object(monitor, "check_aur", side_effect=RuntimeError("network unavailable")), \
                     mock.patch.object(monitor, "check_mise", return_value=[]):
                    after = monitor.check()
                self.assertEqual(after["sources"]["aur"]["items"], [{"name": "existing"}])
                self.assertEqual(after["sources"]["aur"]["checkedAt"], 12)
                self.assertEqual(after["sources"]["aur"]["error"], "network unavailable")

    def test_update_launch_uses_kitty_command_arguments(self):
        with mock.patch.object(monitor.shutil, "which", return_value="/usr/bin/available"), \
             mock.patch.object(monitor.subprocess, "Popen") as spawn:
            monitor.launch("cachy")
            self.assertEqual(spawn.call_args.args[0],
                             ["kitty", "--title", "System updates", "--hold", "cachy-update"])
            monitor.launch("mise")
            self.assertEqual(spawn.call_args.args[0],
                             ["kitty", "--title", "System updates", "--hold",
                              "mise", "--cd", str(monitor.HOME), "upgrade"])

    def test_pacman_only_launch_keeps_interactive_confirmation(self):
        with mock.patch.object(monitor.shutil, "which", return_value="/usr/bin/available"), \
             mock.patch.object(monitor.subprocess, "Popen") as spawn:
            self.assertEqual(monitor.launch("pacman"), {"launched": "pacman"})
            self.assertEqual(spawn.call_args.args[0],
                             ["kitty", "--title", "System updates", "--hold",
                              "sudo", "pacman", "-Syu"])

    def test_pacman_missing_does_not_launch_a_terminal(self):
        with mock.patch.object(monitor.shutil, "which", side_effect=lambda name: None if name == "pacman" else "/usr/bin/available"), \
             mock.patch.object(monitor.subprocess, "Popen") as spawn:
            with self.assertRaisesRegex(RuntimeError, "pacman is unavailable"):
                monitor.launch("pacman")
            spawn.assert_not_called()


    def test_aur_helper_exit_one_means_no_updates(self):
        # paru/yay/pikaur exit 1 when there is nothing to upgrade. Treating
        # that as a failure kept the previous AUR rows on screen and showed a
        # permanent "check incomplete" error.
        completed = subprocess.CompletedProcess([], 1, "", "")
        with mock.patch.object(monitor, "run", return_value=completed), \
             mock.patch.object(monitor.shutil, "which", return_value="/usr/bin/paru"), \
             mock.patch.object(monitor, "configured", return_value=False):
            self.assertEqual(monitor.check_aur(), [])

    def test_aur_helper_real_failure_is_still_reported(self):
        completed = subprocess.CompletedProcess([], 2, "", "network unreachable")
        with mock.patch.object(monitor, "run", return_value=completed), \
             mock.patch.object(monitor.shutil, "which", return_value="/usr/bin/paru"), \
             mock.patch.object(monitor, "configured", return_value=False):
            with self.assertRaisesRegex(RuntimeError, "network unreachable"):
                monitor.check_aur()

if __name__ == "__main__":
    unittest.main()
