import os
import unittest

# Guards the zero-trust Bifrost gateway gate (issue #10) against regression:
# the C# source itself is the contract. If someone strips the auth gate, the
# "done means" of #10 (401 on anonymous requests) silently breaks.
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GATEWAY = os.path.join(ROOT, "Ipc", "BifrostGateway.cs")

with open(GATEWAY, encoding="utf-8") as f:
    GATEWAY_SRC = f.read()


class BifrostGateContract(unittest.TestCase):
    def test_handle_has_401_gate(self):
        self.assertIn("StatusCode = 401", GATEWAY_SRC,
            "gateway must return 401 for unauthenticated requests")

    def test_ws_gate_runs_before_accept(self):
        accept_pos = GATEWAY_SRC.find("AcceptWebSocketAsync")
        gate_pos = GATEWAY_SRC.find("qsToken")
        self.assertGreater(accept_pos, 0)
        self.assertGreater(gate_pos, 0)
        self.assertLess(gate_pos, accept_pos,
            "websocket token check must run BEFORE AcceptWebSocketAsync")

    def test_bearer_header_accepted(self):
        self.assertIn("Bearer ", GATEWAY_SRC)
        self.assertIn("X-StormRaven-Token", GATEWAY_SRC)

    def test_query_string_token_accepted(self):
        self.assertIn('QueryString["token"]', GATEWAY_SRC,
            "browser websockets need ?token= since headers can't be set pre-connect")

    def test_constant_time_compare(self):
        self.assertIn("FixedTimeEquals", GATEWAY_SRC,
            "token comparison must be constant-time")

    def test_fails_closed_without_token_env(self):
        self.assertIn("return false; // fail closed", GATEWAY_SRC,
            "unset STORMRAVEN_GATEWAY_TOKEN must refuse all traffic")
        self.assertIn("string.IsNullOrEmpty(_authToken) || !CryptographicOperations.FixedTimeEquals", GATEWAY_SRC,
            "ws ?token= check must fail closed with 401 when _authToken is unset instead of throwing ArgumentNullException")

    def test_compiles_no_unescaped_quotes(self):
        # Regression for the escaped-quote compile bug found in review.
        self.assertNotIn('realm="stormraven-bifrost""', GATEWAY_SRC)

    def test_runic_and_ravennest_intents_allowlisted(self):
        for intent in ("fehu", "algiz", "isa", "raido", "ravencore", "frostvault", "frostnode", "ymirvault", "echoshell", "demogorgon", "lynn"):
            self.assertIn(f'case "{intent}":', GATEWAY_SRC, f"BifrostGateway must allow-list '{intent}'")

    def test_win11_autounattend_scrubbed_and_checksum_verified(self):
        xml_path = os.path.join(ROOT, "distro", "windows11", "autounattend.xml")
        with open(xml_path, encoding="utf-8") as xf:
            xml_src = xf.read()
        self.assertNotIn("<PlainText>true</PlainText>", xml_src)
        self.assertNotIn("<Value>Stormraven</Value>", xml_src)
        self.assertIn("Get-FileHash", xml_src)
        self.assertIn("install-win11.ps1.sha256", xml_src)

    def test_void_theme_assets_present_in_chroot(self):
        chroot = os.path.join(ROOT, "distro", "live-build", "config", "includes.chroot")
        for rel in (
            ("etc", "gtk-3.0", "gtk.css"),
            ("etc", "gtk-3.0", "settings.ini"),
            ("etc", "xdg", "tint2", "tint2rc"),
            ("etc", "xdg", "openbox", "rc.xml"),
            ("usr", "share", "themes", "StormRaven-Ymir", "openbox-3", "themerc"),
        ):
            self.assertTrue(os.path.isfile(os.path.join(chroot, *rel)), f"Missing Void theme file: {rel}")


    def test_addon_vm_win11_sh_scrubbed_and_checksum_verified(self):
        addon_path = os.path.join(ROOT, "addons", "stormraven-win11-moov-addon", "vm-win11.sh")
        with open(addon_path, encoding="utf-8") as af:
            addon_src = af.read()
        self.assertNotIn("<PlainText>true</PlainText>", addon_src)
        self.assertNotIn("<Value>Stormraven</Value>", addon_src)
        self.assertIn("Get-FileHash", addon_src)
        self.assertNotIn("install-win11.ps1 | iex", addon_src)

    def test_showcase_index_has_no_blind_pipes_and_lists_dual_os_checksums(self):
        showcase_path = os.path.join(ROOT, "webapp", "showcase", "index.html")
        with open(showcase_path, encoding="utf-8") as sf:
            showcase_src = sf.read()
        self.assertNotIn("| sudo bash", showcase_src,
            "showcase/index.html must not contain blind '| sudo bash' pipes")
        self.assertNotIn("| iex", showcase_src,
            "showcase/index.html must not contain blind '| iex' pipes")
        self.assertIn("sha256sum -c", showcase_src,
            "showcase/index.html must verify scripts with sha256sum -c")
        self.assertIn("Get-FileHash", showcase_src,
            "showcase/index.html must verify PowerShell scripts with Get-FileHash")
        self.assertIn("acfe854c42e8e50c4ff50edbf69fd97bb875e1c0264f112b7c24496b" if False else "acfe854c42e8e50c4ff50edbf69fd97bb875e1c0264f636da04f112b7c24496b", showcase_src,
            "showcase/index.html must display the verified Ubuntu 26.04 LTS Ymir ISO SHA-256")
        self.assertIn("4b3d34edd30948e858662a410ee7815f66e1ffdc4ee1d72cbed8f9c3a1ce509b", showcase_src,
            "showcase/index.html must display the verified Windows 11 25H2 Ymir ISO SHA-256")
        self.assertIn("echo-at-faith-s-workspace-2.skydive.app/beta", showcase_src,
            "showcase/index.html must feature the Worldwide 1,000-Slot Beta Portal")


if __name__ == "__main__":
    unittest.main()
