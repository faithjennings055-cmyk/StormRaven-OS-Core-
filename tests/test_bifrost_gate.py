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
            os.path.join(ROOT, "distro", "windows11", "Install-StormRaven-Win10.ps1"),
            os.path.join(ROOT, "distro", "windows11", "Build-StormRaven-Win11-ISO.ps1"),
            os.path.join(ROOT, "distro", "windows11", "Build-StormRaven-Win10-Surface-ISO.ps1"),
            os.path.join(ROOT, "distro", "windows11", "stormraven-skydive.ps1"),
            os.path.join(ROOT, "addons", "stormraven-win11-moov-addon", "install-win11.ps1"),
            os.path.join(ROOT, "releases", "v3.9.0", "install-win11.ps1"),
            os.path.join(ROOT, "releases", "v3.9.0", "install-win10.ps1"),
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

        # Ensure 64-bit Windows 10 Surface installer enforces x64 and excludes Moov commands/shortcuts
        for win10_p in (
            os.path.join(ROOT, "distro", "windows11", "Install-StormRaven-Win10.ps1"),
            os.path.join(ROOT, "releases", "v3.9.0", "install-win10.ps1"),
        ):
            with open(win10_p, "rb") as f:
                w10_txt = f.read()[3:].decode("utf-8")
            self.assertIn("[Environment]::Is64BitOperatingSystem", w10_txt)
            self.assertNotIn(":moov", w10_txt)
            self.assertNotIn("Moov AI Banking", w10_txt)

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

    def test_upgrade_hp_and_recovery_scripts_verify_target_and_fail_closed(self):
        import subprocess
        import tempfile

        upgrade_hp = os.path.join(ROOT, "distro", "upgrade-hp.sh")
        flash_usb = os.path.join(ROOT, "distro", "flash-usb.sh")
        retro_doc = os.path.join(ROOT, "docs", "RETRO_2026_11_16_BOOT_RECOVERY.md")

        self.assertTrue(os.path.isfile(upgrade_hp), "distro/upgrade-hp.sh must exist (#107)")
        self.assertTrue(os.path.isfile(flash_usb), "distro/flash-usb.sh must exist (#107)")
        self.assertTrue(os.path.isfile(retro_doc), "docs/RETRO_2026_11_16_BOOT_RECOVERY.md must exist (#107)")

        with open(upgrade_hp, encoding="utf-8") as uf:
            uhp_src = uf.read()
        self.assertIn("RESOLVED TARGET:", uhp_src)
        self.assertIn("atomic_fetch_and_install", uhp_src)
        self.assertIn("[STEP 1/6]", uhp_src)
        self.assertIn("grub-verify", uhp_src)

        with open(flash_usb, encoding="utf-8") as ff:
            fusb_src = ff.read()
        self.assertIn("--target-label", fusb_src)
        self.assertIn("--target-uuid", fusb_src)
        self.assertIn("RESOLVED TARGET:", fusb_src)

        with tempfile.TemporaryDirectory() as tmpdir:
            fake_blkid = os.path.join(tmpdir, "blkid.tab")
            with open(fake_blkid, "w", encoding="utf-8") as bf:
                bf.write("/dev/sda2 9a8b7c6d-1111-2222-3333-444455556666 STORMRAVEN_ROOT /mnt/hp-root\n")

            env = os.environ.copy()
            env["STORMRAVEN_FAKE_BLKID_FILE"] = fake_blkid

            # 1. Absent LABEL must fail closed (non-zero exit, refuses write)
            res_missing_label = subprocess.run(
                ["bash", upgrade_hp, "--target-label", "NONEXISTENT_LABEL", "--dry-run"],
                env=env,
                capture_output=True,
                text=True,
                timeout=10,
            )
            self.assertNotEqual(res_missing_label.returncode, 0, "upgrade-hp.sh must fail closed when target label is absent")
            self.assertIn("Failing closed", res_missing_label.stderr)

            # 2. Absent UUID must fail closed
            res_missing_uuid = subprocess.run(
                ["bash", upgrade_hp, "--target-uuid", "00000000-0000-0000-0000-000000000000", "--dry-run"],
                env=env,
                capture_output=True,
                text=True,
                timeout=10,
            )
            self.assertNotEqual(res_missing_uuid.returncode, 0, "upgrade-hp.sh must fail closed when target UUID is absent")
            self.assertIn("Failing closed", res_missing_uuid.stderr)

            # 3. Present LABEL without confirmation must refuse write when user enters anything other than UPGRADE
            res_unconfirmed = subprocess.run(
                ["bash", upgrade_hp, "--target-label", "STORMRAVEN_ROOT", "--dry-run"],
                input="no\n",
                env=env,
                capture_output=True,
                text=True,
                timeout=10,
            )
            self.assertNotEqual(res_unconfirmed.returncode, 0, "upgrade-hp.sh must refuse write when confirmation is declined")
            self.assertIn("RESOLVED TARGET:", res_unconfirmed.stdout)
            self.assertIn("Cancelled. Nothing was written.", res_unconfirmed.stdout)

            # 4. Present LABEL + explicit UPGRADE confirmation prints RESOLVED TARGET and succeeds in dry-run
            res_confirmed = subprocess.run(
                ["bash", upgrade_hp, "--target-label", "STORMRAVEN_ROOT", "--dry-run"],
                input="UPGRADE\n",
                env=env,
                capture_output=True,
                text=True,
                timeout=10,
            )
            self.assertEqual(res_confirmed.returncode, 0, f"Expected 0 on confirmed target, got: {res_confirmed.stderr}")
            self.assertIn("RESOLVED TARGET:", res_confirmed.stdout)
            self.assertIn("9a8b7c6d-1111-2222-3333-444455556666", res_confirmed.stdout)
            self.assertIn("[STEP 1/6] DRY-RUN:", res_confirmed.stdout)

    def test_issue_108_recovery_and_flashing_scripts_enforce_serial_verify_mode_and_sidecars(self):
        import hashlib
        import subprocess
        import tempfile

        bash_scripts = [
            os.path.join(ROOT, "distro", "flash-usb.sh"),
            os.path.join(ROOT, "distro", "upgrade-hp.sh"),
            os.path.join(ROOT, "distro", "make-ventoy-usb.sh"),
            os.path.join(ROOT, "distro", "make-surface3-usb.sh"),
            os.path.join(ROOT, "distro", "make-win11-usb.sh"),
            os.path.join(ROOT, "distro", "make-win10-surface-usb.sh"),
            os.path.join(ROOT, "distro", "install-chromebook.sh"),
            os.path.join(ROOT, "distro", "live-build", "config", "includes.chroot", "usr", "local", "bin", "stormraven-dualboot"),
            os.path.join(ROOT, "distro", "live-build", "config", "includes.chroot", "usr", "local", "bin", "stormraven-installer"),
        ]
        ps1_scripts = [
            os.path.join(ROOT, "distro", "write-micro-sd.ps1"),
            os.path.join(ROOT, "distro", "write-infinity-sd.ps1"),
            os.path.join(ROOT, "distro", "make-linux-sd-surface3.ps1"),
            os.path.join(ROOT, "distro", "Make-Surface3-USB.ps1"),
        ]

        # 1. Verify regression story (#108), --verify-mode / -VerifyMode, ERASE gate, and exact .sha256 sidecars
        for s in bash_scripts:
            self.assertTrue(os.path.isfile(s), f"Missing recovery script: {s}")
            with open(s, encoding="utf-8") as fh:
                src = fh.read()
            self.assertIn("#108", src, f"{s} must document the Issue #108 regression story in header")
            self.assertIn("verify-mode", src, f"{s} must implement --verify-mode")
            self.assertIn("RESOLVED TARGET:", src, f"{s} must print RESOLVED TARGET before writing")
            sidecar = s + ".sha256"
            if os.path.isfile(sidecar):
                with open(s, "rb") as sb:
                    actual_sha = hashlib.sha256(sb.read()).hexdigest()
                with open(sidecar, encoding="utf-8") as sc:
                    expected_sha = sc.read().split()[0].strip()
                self.assertEqual(actual_sha, expected_sha, f"Stale .sha256 sidecar for {s}")

        for p in ps1_scripts:
            self.assertTrue(os.path.isfile(p), f"Missing PowerShell recovery script: {p}")
            with open(p, encoding="utf-8") as fh:
                src = fh.read()
            self.assertIn("#108", src, f"{p} must document the Issue #108 regression story in header")
            self.assertIn("VerifyMode", src, f"{p} must implement -VerifyMode")
            self.assertIn("RESOLVED TARGET", src, f"{p} must print RESOLVED TARGET before writing")
            sidecar = p + ".sha256"
            self.assertTrue(os.path.isfile(sidecar), f"Missing .sha256 sidecar for {p}")
            with open(p, "rb") as pb:
                actual_sha = hashlib.sha256(pb.read()).hexdigest()
            with open(sidecar, encoding="utf-8") as sc:
                expected_sha = sc.read().split()[0].strip()
            self.assertEqual(actual_sha, expected_sha, f"Stale .sha256 sidecar for {p}")

        # 2. Exercise --verify-mode interactively with fake lsblk table (matching serial resolves, unknown serial fails closed)
        with tempfile.TemporaryDirectory() as tmpdir:
            fake_lsblk = os.path.join(tmpdir, "lsblk.txt")
            with open(fake_lsblk, "w", encoding="utf-8") as lf:
                lf.write(
                    "NAME SIZE MODEL SERIAL TRAN RM TYPE\n"
                    "mmcblk0 58.2G HBG4e 0x99887766 mmc 0 disk\n"
                    "sdb 465.8G WD5000BEVT WD-WX91A9012345 usb 0 disk\n"
                )
            env = os.environ.copy()
            env["STORMRAVEN_FAKE_LSBLK_FILE"] = fake_lsblk

            for s in bash_scripts:
                ok_res = subprocess.run(
                    ["bash", s, "--verify-mode"],
                    input="WD-WX91A9012345\n",
                    env=env,
                    capture_output=True,
                    text=True,
                    timeout=10,
                )
                self.assertEqual(ok_res.returncode, 0, f"--verify-mode failed on valid serial in {s}: {ok_res.stderr}")
                self.assertIn("RESOLVED TARGET:", ok_res.stdout)
                self.assertIn("/dev/sdb", ok_res.stdout)

                bad_res = subprocess.run(
                    ["bash", s, "--verify-mode"],
                    input="WRONG-SERIAL-999\n",
                    env=env,
                    capture_output=True,
                    text=True,
                    timeout=10,
                )
                self.assertNotEqual(bad_res.returncode, 0, f"--verify-mode must fail closed on unknown serial in {s}")
                self.assertIn("Failing closed", bad_res.stderr)


    def test_issue_110_iso_verification_gate_rejects_zero_byte_efi_and_missing_mbr(self):
        import tempfile, hashlib, subprocess
        gate = os.path.join(ROOT, "distro", "ci", "verify-iso-gate.sh")
        self.assertTrue(os.path.isfile(gate), "Missing distro/ci/verify-iso-gate.sh")
        with tempfile.TemporaryDirectory() as tmpdir:
            iso_path = os.path.join(tmpdir, "test.iso")
            buf = bytearray(0x12000)
            buf[0x8001:0x8006] = b"CD001"
            with open(iso_path, "wb") as f:
                f.write(buf)
            sha = hashlib.sha256(buf).hexdigest()
            with open(iso_path + ".sha256", "w", encoding="utf-8") as f:
                f.write(f"{sha}  test.iso\n")
            res_no_mbr = subprocess.run(["bash", gate, iso_path], capture_output=True, text=True, timeout=10)
            self.assertNotEqual(res_no_mbr.returncode, 0)
            self.assertIn("0x55AA", res_no_mbr.stderr)

            buf[510:512] = b"\x55\xaa"
            with open(iso_path, "wb") as f:
                f.write(buf)
            sha2 = hashlib.sha256(buf).hexdigest()
            with open(iso_path + ".sha256", "w", encoding="utf-8") as f:
                f.write(f"{sha2}  test.iso\n")
            res_ok = subprocess.run(["bash", gate, iso_path], capture_output=True, text=True, timeout=10)
            self.assertEqual(res_ok.returncode, 0, res_ok.stderr)
            self.assertIn("[PASS]", res_ok.stdout)



    def test_hp_storage_setup_enforces_serial_resolution_and_grub_uuid_gate(self):
        script = ROOT / "distro/live-build/config/includes.chroot/usr/local/bin/stormraven-hp-storage-setup"
        content = script.read_text(encoding="utf-8")
        self.assertIn("--dry-run", content)
        self.assertIn("resolve_disk_by_model", content)
        self.assertIn("lsblk -dn -o NAME,MODEL,SERIAL,SIZE", content)
        self.assertIn('if [ "$CONFIRM" != "ERASE" ]', content)
        self.assertIn('grep -q "$ROOT_UUID" "$TMP_GRUB"', content)
        self.assertIn("/file/win11", content)


if __name__ == "__main__":
    unittest.main()
