"""Tests for the two highest-risk Pantheon modules: ragnarok (filesystem purge)
and deadman (kill switch).

These modules contain destructive side effects (shutil.rmtree, os.system kernel
panic / taskkill, subprocess launching ragnarok). Every test here mocks those
boundaries so the test run itself can NEVER delete a real directory, crash the
kernel, kill a process, or launch ragnarok. We verify the control flow and the
destructive intent, not the destruction.
"""
import os
import sys
import unittest
from unittest import mock

# Put StormRaven.Python on sys.path so Pantheon modules import cleanly, matching
# the convention in test_pantheon.py.
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PANTHEON_DIR = os.path.join(ROOT, "StormRaven.Python")
if PANTHEON_DIR not in sys.path:
    sys.path.insert(0, PANTHEON_DIR)

import ragnarok  # noqa: E402
import deadman  # noqa: E402


class TestRagnarok(unittest.TestCase):
    """ragnarok.purge() wipes the forensic log dir then crashes the host.
    We confirm it does both, and that a failed rmtree does not abort the crash.
    All destructive calls are mocked."""

    def test_purge_removes_log_dir_when_present(self):
        with mock.patch.object(ragnarok.os.path, "exists", return_value=True), \
             mock.patch.object(ragnarok.shutil, "rmtree") as rmtree, \
             mock.patch.object(ragnarok, "IS_WINDOWS", False), \
             mock.patch.object(ragnarok.os, "system") as system:
            ragnarok.purge()
            rmtree.assert_called_once_with(ragnarok.LOG_DIR)
            # Linux branch fires both panic triggers.
            self.assertEqual(system.call_count, 2)
            calls = [c.args[0] for c in system.call_args_list]
            self.assertIn("echo 1 > /proc/sys/kernel/panic", calls)
            self.assertIn("echo c > /proc/sysrq-trigger", calls)

    def test_purge_skips_rmtree_when_log_dir_absent(self):
        with mock.patch.object(ragnarok.os.path, "exists", return_value=False), \
             mock.patch.object(ragnarok.shutil, "rmtree") as rmtree, \
             mock.patch.object(ragnarok, "IS_WINDOWS", False), \
             mock.patch.object(ragnarok.os, "system") as system:
            ragnarok.purge()
            rmtree.assert_not_called()
            # Crash still happens even if there was nothing to purge.
            self.assertEqual(system.call_count, 2)

    def test_purge_still_crashes_when_rmtree_raises(self):
        # The bare except in purge() must swallow a failed wipe and continue to
        # the crash. This guards against a regression where a purge error
        # silently leaves the host alive.
        with mock.patch.object(ragnarok.os.path, "exists", return_value=True), \
             mock.patch.object(ragnarok.shutil, "rmtree",
                               side_effect=PermissionError("denied")), \
             mock.patch.object(ragnarok, "IS_WINDOWS", False), \
             mock.patch.object(ragnarok.os, "system") as system:
            ragnarok.purge()  # must not raise
            self.assertEqual(system.call_count, 2)

    def test_purge_windows_branch_uses_taskkill(self):
        with mock.patch.object(ragnarok.os.path, "exists", return_value=False), \
             mock.patch.object(ragnarok.shutil, "rmtree"), \
             mock.patch.object(ragnarok, "IS_WINDOWS", True), \
             mock.patch.object(ragnarok.os, "system") as system:
            ragnarok.purge()
            system.assert_called_once()
            self.assertIn("taskkill", system.call_args.args[0])


class TestDeadman(unittest.TestCase):
    """deadman.monitor() loops forever watching DEV_DRIVE; if the drive
    disappears it runs ragnarok. We drive the loop a fixed number of times by
    patching time.sleep to raise once we've observed enough iterations, so the
    test terminates deterministically and never actually launches ragnarok."""

    class _StopLoop(Exception):
        pass

    def _run_monitor_once(self, drive_present):
        """Run monitor through exactly one evaluation of the safety check.
        Returns the mocked subprocess.run so the caller can assert on it."""
        # time.sleep is called first (startup 60s), then once per loop. We let
        # the startup sleep pass, then break out on the in-loop sleep so the
        # while-True terminates after a single evaluation.
        sleep_calls = {"n": 0}

        def fake_sleep(_seconds):
            sleep_calls["n"] += 1
            if sleep_calls["n"] >= 2:  # 1 = startup, 2 = end of first loop
                raise self._StopLoop()

        with mock.patch.object(deadman, "IS_WINDOWS", False), \
             mock.patch.object(deadman.os.path, "ismount",
                               return_value=drive_present), \
             mock.patch.object(deadman.time, "sleep", side_effect=fake_sleep), \
             mock.patch.object(deadman.subprocess, "run") as run:
            with self.assertRaises(self._StopLoop):
                deadman.monitor()
            return run

    def test_monitor_does_not_trigger_ragnarok_when_drive_present(self):
        run = self._run_monitor_once(drive_present=True)
        run.assert_not_called()

    def test_monitor_triggers_ragnarok_when_drive_missing(self):
        run = self._run_monitor_once(drive_present=False)
        run.assert_called_once()
        # It launches ragnarok.py as a subprocess.
        self.assertIn("ragnarok.py", run.call_args.args[0])

    def test_monitor_windows_uses_path_exists(self):
        sleep_calls = {"n": 0}

        def fake_sleep(_seconds):
            sleep_calls["n"] += 1
            if sleep_calls["n"] >= 2:
                raise self._StopLoop()

        with mock.patch.object(deadman, "IS_WINDOWS", True), \
             mock.patch.object(deadman.os.path, "exists",
                               return_value=False) as exists, \
             mock.patch.object(deadman.time, "sleep", side_effect=fake_sleep), \
             mock.patch.object(deadman.subprocess, "run") as run:
            with self.assertRaises(self._StopLoop):
                deadman.monitor()
            exists.assert_called_with(deadman.DEV_DRIVE)
            run.assert_called_once()


if __name__ == "__main__":
    unittest.main()
