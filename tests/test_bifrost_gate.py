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
        for intent in ("fehu", "algiz", "isa", "raido", "ravencore", "frostvault", "frostnode", "ymirvault", "echoshell", "demogorgon", "lynn", "war_room", "wsu_status", "wsu_cell_heartbeat", "wsu_scan_shared", "skydive"):
            self.assertIn(f'case "{intent}":', GATEWAY_SRC, f"BifrostGateway must allow-list '{intent}'")

    def test_ymir_security_war_room_panel_and_chroot_python_hardened(self):
        chroot_webapp = os.path.join(
            ROOT, "distro", "live-build", "config", "includes.chroot", "opt", "stormraven", "webapp"
        )
        with open(os.path.join(chroot_webapp, "index.html"), encoding="utf-8") as hf:
            html_src = hf.read()
        with open(os.path.join(chroot_webapp, "app.js"), encoding="utf-8") as jf:
            js_src = jf.read()
        self.assertIn("Security War Room", html_src)
        self.assertIn("view-freya", html_src)
        self.assertIn("applyWholeSystemRealm", js_src)
        self.assertNotIn("| bash", html_src)
        self.assertNotIn("| bash", js_src)
        self.assertNotIn("| iex", js_src)

        chroot_py = os.path.join(
            ROOT, "distro", "live-build", "config", "includes.chroot", "opt", "stormraven", "python"
        )
        with open(os.path.join(chroot_py, "bifrost.py"), encoding="utf-8") as bf:
            b_src = bf.read()
        with open(os.path.join(chroot_py, "thor.py"), encoding="utf-8") as tf:
            t_src = tf.read()
        self.assertNotIn("echo {intent}", b_src, "chroot bifrost.py must not have echo fallback")
        self.assertIn("shell=False", t_src, "chroot thor.py must enforce shell=False")

    def test_win11_autounattend_scrubbed_and_checksum_verified(self):
        xml_path = os.path.join(ROOT, "distro", "windows11", "autounattend.xml")
        with open(xml_path, encoding="utf-8") as xf:
            xml_src = xf.read()
        self.assertNotIn("<PlainText>true</PlainText>", xml_src)
        self.assertNotIn("<Value>Stormraven</Value>", xml_src)
        self.assertIn("Get-FileHash", xml_src)
        self.assertIn("install-win11.ps1.sha256", xml_src)
        # Issue #97: Ensure WindowsPE LabConfig hardware check bypasses are present
        self.assertIn('pass="windowsPE"', xml_src)
        for key in ("BypassTPMCheck", "BypassSecureBootCheck", "BypassRAMCheck", "BypassStorageCheck", "BypassCPUCheck"):
            self.assertIn(key, xml_src, f"autounattend.xml must include LabConfig {key} (#97)")

    def test_win11_iso_builders_assert_autounattend_and_labconfig_bypass(self):
        sh_path = os.path.join(ROOT, "distro", "build-win11-iso.sh")
        ps1_path = os.path.join(ROOT, "distro", "windows11", "Build-StormRaven-Win11-ISO.ps1")
        with open(sh_path, encoding="utf-8") as sf:
            sh_src = sf.read()
        with open(ps1_path, encoding="utf-8") as pf:
            ps1_src = pf.read()
        for key in ("BypassTPMCheck", "BypassSecureBootCheck", "BypassRAMCheck", "BypassStorageCheck", "BypassCPUCheck"):
            self.assertIn(key, sh_src, f"build-win11-iso.sh must assert LabConfig {key} (#97)")
            self.assertIn(key, ps1_src, f"Build-StormRaven-Win11-ISO.ps1 must inject/assert LabConfig {key} (#97)")
        self.assertIn("CRITICAL BUILD FAILURE (#97)", sh_src)
        self.assertIn("CRITICAL BUILD FAILURE (#97)", ps1_src)

    def test_all_repo_sha256_sidecars_match_their_artifacts(self):
        import glob
        import hashlib
        checked = 0
        for dirpath, _dirnames, filenames in os.walk(ROOT):
            if ".git" in dirpath.split(os.sep):
                continue
            for fn in filenames:
                if not fn.endswith(".sha256"):
                    continue
                sidecar_path = os.path.join(dirpath, fn)
                with open(sidecar_path, encoding="utf-8") as sf:
                    line = sf.read().strip()
                parts = line.split()
                self.assertGreaterEqual(len(parts), 2, f"Malformed .sha256 sidecar: {sidecar_path}")
                expected_sha = parts[0].lower()
                target_name = parts[-1].lstrip("*")
                target_path = os.path.join(dirpath, target_name)
                part_paths = sorted(glob.glob(target_path + ".part*"))
                self.assertTrue(
                    os.path.isfile(target_path) or len(part_paths) > 0,
                    f"Missing artifact {target_path} (or .part* chunks) for sidecar {sidecar_path}",
                )
                h = hashlib.sha256()
                sources = [target_path] if os.path.isfile(target_path) else part_paths
                for src_path in sources:
                    with open(src_path, "rb") as tf:
                        for chunk in iter(lambda: tf.read(65536), b""):
                            h.update(chunk)
                self.assertEqual(h.hexdigest().lower(), expected_sha,
                    f"Stale .sha256 sidecar {sidecar_path}: expected {expected_sha}, got {h.hexdigest().lower()}")
                checked += 1
        self.assertGreaterEqual(checked, 10, "Expected at least 10 .sha256 sidecars in repo")

    def test_win11_ps1_scripts_with_non_ascii_have_utf8_bom_and_no_blind_iex(self):
        ps1_paths = [
            os.path.join(ROOT, "distro", "windows11", "Install-StormRaven-Win11.ps1"),
            os.path.join(ROOT, "distro", "windows11", "Build-StormRaven-Win11-ISO.ps1"),
            os.path.join(ROOT, "distro", "windows11", "stormraven-skydive.ps1"),
            os.path.join(ROOT, "addons", "stormraven-win11-moov-addon", "install-win11.ps1"),
            os.path.join(ROOT, "releases", "v3.9.0", "install-win11.ps1"),
        ]
        for p in ps1_paths:
            self.assertTrue(os.path.isfile(p), f"Missing PowerShell script: {p}")
            with open(p, "rb") as f:
                raw = f.read()
            self.assertTrue(
                raw.startswith(b"\xef\xbb\xbf"),
                f"PowerShell script {p} must start with UTF-8 BOM (EF BB BF) for Windows PowerShell 5.1 (#105)",
            )
            text = raw[3:].decode("utf-8")
            self.assertNotIn("| iex", text, f"PowerShell script {p} must not contain blind '| iex' pipes (#105)")

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

    def test_ios_mdm_and_mobileconfig_profiles_pass_strict_plistlib_validation(self):
        import plistlib
        import uuid

        profiles_dir = os.path.join(ROOT, "releases", "v3.9.0", "profiles")
        self.assertTrue(os.path.isdir(profiles_dir), f"Missing profiles directory: {profiles_dir}")
        checked_profiles = 0
        for fname in sorted(os.listdir(profiles_dir)):
            if not (fname.endswith(".mobileconfig") or fname.endswith(".mdm")):
                continue
            fpath = os.path.join(profiles_dir, fname)
            with open(fpath, "rb") as pf:
                data = plistlib.load(pf)
            self.assertEqual(data.get("PayloadType"), "Configuration", f"{fname} must have PayloadType=Configuration")
            self.assertEqual(data.get("PayloadVersion"), 1, f"{fname} must have PayloadVersion=1")
            uuid.UUID(data["PayloadUUID"])
            content = data.get("PayloadContent", [])
            self.assertGreaterEqual(len(content), 1, f"{fname} must contain at least 1 payload")
            for item in content:
                uuid.UUID(item["PayloadUUID"])
            checked_profiles += 1
        self.assertGreaterEqual(checked_profiles, 6, "Expected at least 6 validated .mobileconfig/.mdm profiles")


if __name__ == "__main__":
    unittest.main()
