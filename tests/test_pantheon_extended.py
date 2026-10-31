import os
import sys
import unittest
from unittest.mock import patch, MagicMock

# Put StormRaven.Python on sys.path
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PANTHEON_DIR = os.path.join(ROOT, "StormRaven.Python")
if PANTHEON_DIR not in sys.path:
    sys.path.insert(0, PANTHEON_DIR)

from thor import Thor
from saga import Saga
import solomon
import luci
import lynn
import heketa
import shadow_log
import void_viz

class TestPantheonExtended(unittest.TestCase):
    def test_thor_telemetry(self):
        thor = Thor()
        res = thor.get_telemetry()
        self.assertIn("cpu", res)
        self.assertIn("ram", res)
        self.assertIn("connections", res)

    @patch("subprocess.run")
    def test_thor_strike(self, mock_run):
        thor = Thor()
        res = thor.strike_system("echo hello")
        self.assertTrue(res["success"])
        mock_run.assert_called_once()

    def test_saga_speak(self):
        saga = Saga()
        # speak() is currently a no-op, just testing it doesn't crash
        saga.speak("Hello")

    @patch("os.path.exists")
    @patch("os.path.ismount")
    def test_solomon_seal(self, mock_ismount, mock_exists):
        mock_exists.return_value = True
        mock_ismount.return_value = True
        self.assertTrue(solomon.check_seal())

    @patch("os.path.exists")
    def test_luci_verify(self, mock_exists):
        mock_exists.return_value = True
        self.assertTrue(luci.verify_key())

    def test_lynn_status(self):
        # verify it runs without error
        lynn.status()

    def test_heketa_audit(self):
        # verify it runs without error
        heketa.run_audit()

    @patch("os.path.exists")
    @patch("builtins.open", new_callable=unittest.mock.mock_open)
    def test_shadow_log_write(self, mock_file, mock_exists):
        mock_exists.return_value = True
        shadow_log.write_telemetry(10, ["1.1.1.1"])
        mock_file().write.assert_called()

    @patch("os.path.exists")
    @patch("builtins.open", new_callable=unittest.mock.mock_open, read_data='{"ts": "2026-10-30T12:00:00", "count": 5}\\n')
    def test_void_viz_render(self, mock_file, mock_exists):
        mock_exists.return_value = True
        # Test that render doesn't crash with valid data
        void_viz.render()

if __name__ == "__main__":
    unittest.main()
