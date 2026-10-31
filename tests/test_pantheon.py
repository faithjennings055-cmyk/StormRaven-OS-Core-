import os
import sys
import unittest

# Put StormRaven.Python on sys.path so Pantheon modules import cleanly
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PANTHEON_DIR = os.path.join(ROOT, "StormRaven.Python")
if PANTHEON_DIR not in sys.path:
    sys.path.insert(0, PANTHEON_DIR)

from bifrost import Bifrost  # noqa: E402
from freya import Freya  # noqa: E402
from heimdall import Heimdall  # noqa: E402
from odin import Odin  # noqa: E402


class TestStormRavenPantheon(unittest.TestCase):
    def test_heimdall_audit_blocks_destructive_commands(self):
        guard = Heimdall()
        self.assertTrue(guard.audit("ip a"))
        self.assertTrue(guard.audit("uname -srm"))
        self.assertFalse(guard.audit("rm -rf /"))
        self.assertFalse(guard.audit(":(){ :|:& };:"))

    def test_bifrost_translate_command(self):
        bridge = Bifrost()
        res = bridge.translate_command("check_ip")
        self.assertTrue(res["valid"])
        self.assertIn(res["cmd"], ("ip a", "ipconfig"))

    def test_freya_autonomous_mind(self):
        mind = Freya()
        self.assertIsNone(mind.think_autonomously({"cpu": 25.0, "ram": 40.0}))
        high_cpu = mind.think_autonomously({"cpu": 95.0, "ram": 40.0})
        self.assertIsNotNone(high_cpu)
        self.assertEqual(high_cpu["intent"], "kill_bloatware")

    def test_odin_execute_telemetry_and_heimdall(self):
        odin = Odin(quiet=True)
        telemetry_res = odin.execute_command("telemetry")
        self.assertTrue(telemetry_res["ok"])
        self.assertIn("Ubuntu 24.04", telemetry_res["distro"])
        self.assertIn("cpu", telemetry_res["telemetry"])

        audit_res = odin.execute_command("heimdall_scan")
        self.assertTrue(audit_res["ok"])
        self.assertEqual(audit_res["status"], "SHIELD_ACTIVE")


if __name__ == "__main__":
    unittest.main()
