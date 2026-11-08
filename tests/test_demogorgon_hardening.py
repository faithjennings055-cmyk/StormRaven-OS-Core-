"""Contract and integration tests for Core issues #89, #91, and #92:
- Demogorgon Endlessh slow-banner tarpit + Loki JSONL/SQLite logging + Valkyrie alerts (#92)
- Lynn Honeycomb Defense reading Demogorgon logs (#92)
- Bifrost secret scrubbing & /api/vault lock (#92)
- Compendium Hardening Matrix (sysctl, ephemeral tmpfs, service sandboxing, and live-sudo regression guard #58) (#89)
- Compendium Accuracy Audit separating real architecture from narrative flavor (#91)
"""
import json
import os
import socket
import sys
import tempfile
import time
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
for d in ("StormRaven.Python", "Python"):
    p = os.path.join(ROOT, d)
    if p not in sys.path:
        sys.path.insert(0, p)

from loki import Loki  # noqa: E402
from demogorgon import Demogorgon  # noqa: E402
import lynn  # noqa: E402
from bifrost import Bifrost  # noqa: E402


class DemogorgonAndHardeningContract(unittest.TestCase):
    def test_loki_writes_jsonl_and_sqlite_and_detects_first_contact(self):
        with tempfile.TemporaryDirectory() as tmp:
            logger = Loki(log_dir=tmp, db_path=os.path.join(tmp, "demogorgon.db"))
            first = logger.write_event(
                "Demogorgon",
                "Intrusion Attempt",
                "203.0.113.77",
                "Probe 1",
                src_port=41234,
                dst_port=2222,
                banner_served="Welcome to the Upside Down.",
                bytes_sent=128,
                hold_duration_sec=1.25,
                probes=2,
            )
            self.assertTrue(first["firstContact"])
            self.assertTrue(first["valkyrieAlert"])

            second = logger.write_event(
                "Demogorgon",
                "Intrusion Attempt",
                "203.0.113.77",
                "Probe 2",
                src_port=41235,
                dst_port=2222,
                banner_served="Welcome to the Upside Down.",
                bytes_sent=64,
                hold_duration_sec=0.75,
                probes=1,
            )
            self.assertFalse(second["firstContact"])
            self.assertFalse(second["valkyrieAlert"])

            stats = logger.summary_stats()
            self.assertEqual(stats["totalEvents"], 2)
            self.assertEqual(stats["uniqueSourceIps"], 1)
            self.assertEqual(stats["totalBytesSent"], 192)
            self.assertEqual(stats["valkyrieAlerts"], 1)

            with open(logger.jsonl_path, encoding="utf-8") as jf:
                lines = [json.loads(line) for line in jf if line.strip()]
            self.assertEqual(len(lines), 2)
            self.assertEqual(lines[0]["srcIp"], "203.0.113.77")

    def test_demogorgon_endlessh_hold_and_logging(self):
        with tempfile.TemporaryDirectory() as tmp:
            logger = Loki(log_dir=tmp, db_path=os.path.join(tmp, "demogorgon.db"))
            # Bind on an ephemeral port with 0.08s line delay and 3 lines (~0.16s hold)
            trap = Demogorgon(port=0, line_delay_sec=0.08, max_hold_sec=0.5, max_lines=3, logger=logger)
            trap.awaken()
            try:
                for _ in range(20):
                    if trap.socket is not None and trap.port != 0:
                        break
                    time.sleep(0.02)
                self.assertGreater(trap.port, 0)

                t0 = time.monotonic()
                with socket.create_connection(("127.0.0.1", trap.port), timeout=2.0) as s:
                    s.sendall(b"SSH-2.0-Scanner\r\n")
                    chunks = []
                    while True:
                        data = s.recv(1024)
                        if not data:
                            break
                        chunks.append(data)
                elapsed = time.monotonic() - t0
                banner = b"".join(chunks).decode("utf-8", errors="replace")
                self.assertIn("Welcome to the Upside Down", banner)
                self.assertIn("Endlessh slow-banner hold", banner)
                self.assertGreaterEqual(elapsed, 0.12, "Endlessh tarpit must hold connection across multiple slow banner lines")

                # Wait briefly for handler thread to commit SQLite row
                for _ in range(20):
                    if logger.summary_stats()["uniqueSourceIps"] >= 1:
                        break
                    time.sleep(0.02)
                incidents = logger.recent_incidents(limit=5)
                intrusion = next((i for i in incidents if i["eventType"] == "Intrusion Attempt"), None)
                self.assertIsNotNone(intrusion)
                self.assertGreater(intrusion["bytesSent"], 80)
                self.assertGreaterEqual(intrusion["holdDurationSec"], 0.10)
                self.assertTrue(intrusion["firstContact"])
                self.assertTrue(intrusion["valkyrieAlert"])
            finally:
                trap.banish()

    def test_lynn_reads_demogorgon_logs(self):
        st = lynn.status()
        self.assertEqual(st["cells"], 616)
        self.assertIn("demogorgon", st)
        self.assertIn("summary", st["demogorgon"])

    def test_bifrost_has_no_hardcoded_secrets_or_vault_dump(self):
        for rel in (("StormRaven.Python", "bifrost.py"), ("Python", "bifrost.py"), ("StormRaven.Python", "stormraven_local_gateway.py")):
            fpath = os.path.join(ROOT, *rel)
            with open(fpath, encoding="utf-8") as f:
                src = f.read()
            self.assertNotIn("stormraven_obsidian_key", src)
            self.assertNotIn("CRYPTOGRAPHIC VAULT BREACHED", src)
        self.assertFalse(Bifrost.VAULT_DUMP_ENABLED)
        self.assertFalse(Bifrost.verify_gateway_token("wrong", "expected"))
        self.assertTrue(Bifrost.verify_gateway_token("expected", "expected"))

    def test_compendium_hardening_matrix_and_live_sudo_regression_guard(self):
        sysctl_path = os.path.join(
            ROOT, "distro", "live-build", "config", "includes.chroot", "etc", "sysctl.d", "99-storm-raven.conf"
        )
        self.assertTrue(os.path.isfile(sysctl_path))
        with open(sysctl_path, encoding="utf-8") as sf:
            sysctl_src = sf.read()
        for expected in (
            "kernel.randomize_va_space = 2",
            "kernel.dmesg_restrict = 1",
            "kernel.yama.ptrace_scope = 2",
            "kernel.kptr_restrict = 2",
            "net.core.bpf_jit_harden = 2",
            "net.ipv4.icmp_echo_ignore_all = 1",
            "net.ipv4.tcp_syncookies = 1",
            "net.ipv4.conf.all.rp_filter = 1",
            "net.ipv4.conf.all.accept_redirects = 0",
            "net.ipv4.conf.all.log_martians = 1",
        ):
            self.assertIn(expected, sysctl_src)

        hardening_script = os.path.join(
            ROOT, "distro", "live-build", "config", "includes.chroot", "usr", "local", "bin", "stormraven-hardening"
        )
        self.assertTrue(os.path.isfile(hardening_script))
        with open(hardening_script, encoding="utf-8") as hf:
            h_src = hf.read()
        # Critical regression guard (#58): sudo must NEVER be in SUID_STRIP_TARGETS and must be enforced 04755 + NOPASSWD
        self.assertIn("chmod 04755 /usr/bin/sudo", h_src)
        self.assertIn("NOPASSWD: ALL", h_src)

        for svc_rel in (
            ("distro", "live-build", "config", "includes.chroot", "etc", "systemd", "system", "stormraven-kernel.service"),
            ("distro", "live-build", "config", "includes.chroot", "etc", "systemd", "system", "stormraven-demogorgon.service"),
            ("distro", "systemd", "stormraven-kernel.service"),
        ):
            svc_path = os.path.join(ROOT, *svc_rel)
            with open(svc_path, encoding="utf-8") as svf:
                svc_src = svf.read()
            self.assertIn("NoNewPrivileges=true", svc_src)
            self.assertIn("ProtectSystem=full", svc_src)
            self.assertIn("PrivateTmp=true", svc_src)

    def test_compendium_accuracy_audit_present(self):
        audit_path = os.path.join(ROOT, "docs", "COMPENDIUM_ACCURACY_AUDIT.md")
        self.assertTrue(os.path.isfile(audit_path))
        with open(audit_path, encoding="utf-8") as af:
            audit_src = af.read()
        self.assertIn("NARRATIVE FLAVOR", audit_src)
        self.assertIn("AES-GCM-512-NEON", audit_src)
        self.assertIn("SOCIOPATH-LLC", audit_src)
        self.assertIn("LAB-ONLY (EXCLUDED FROM ISO)", audit_src)

    def test_provenance_and_durable_mirror_contract(self):
        prov_path = os.path.join(ROOT, "distro", "PROVENANCE.json")
        self.assertTrue(os.path.isfile(prov_path), "distro/PROVENANCE.json must exist (#95)")
        with open(prov_path, encoding="utf-8") as pf:
            prov = json.load(pf)
        self.assertIn("ubuntu2604Iso", prov.get("artifacts", {}))
        self.assertIn("windows11YmirIso", prov.get("artifacts", {}))
        for builder_rel in (("distro", "build-ubuntu-iso.sh"), ("distro", "build-win11-iso.sh")):
            bpath = os.path.join(ROOT, *builder_rel)
            with open(bpath, encoding="utf-8") as bf:
                bsrc = bf.read()
            self.assertIn("STORMRAVEN_ARTIFACT_MIRROR_DIR", bsrc)
            self.assertIn("PROVENANCE.json", bsrc)

    def test_wsu_sovereign_cell_per_install_key_and_rdp_cert_pinning(self):
        import subprocess
        wsu_path = os.path.join(
            ROOT, "distro", "live-build", "config", "includes.chroot", "usr", "local", "bin", "stormraven-wsu"
        )
        self.assertTrue(os.path.isfile(wsu_path))
        with open(wsu_path, encoding="utf-8") as wf:
            wsu_src = wf.read()
        # Follow-up 1 & 2 (#96): no hardcoded public fallback key and no /cert:ignore
        self.assertNotIn("SR-LUCI-INFINITY-SOVEREIGN-KEY-v3.3", wsu_src)
        self.assertNotIn("/cert:ignore", wsu_src)
        self.assertIn("/cert:fingerprint:sha256:", wsu_src)
        self.assertIn("/cert:tofu", wsu_src)

        with tempfile.TemporaryDirectory() as tmp:
            env = os.environ.copy()
            env["STORMRAVEN_WSU_DIR"] = os.path.join(tmp, "wsu")
            env["STORMRAVEN_VOID_DIR"] = os.path.join(tmp, "void")
            env["DRY_RUN"] = "1"
            # 1. Heartbeat auto-generates per-install Luci.key and passes verify-ipc
            hb = subprocess.run(["/bin/bash", wsu_path, "cell", "heartbeat"], env=env, capture_output=True, text=True, check=True)
            hb_json = json.loads(hb.stdout.strip())
            self.assertTrue(hb_json["ok"])
            self.assertEqual(hb_json["verdict"], "PASS")
            self.assertTrue(os.path.isfile(os.path.join(tmp, "wsu", "Luci.key")))

            # 2. Replay of the exact same nonce is blocked
            with open(os.path.join(tmp, "wsu", "Luci.key"), encoding="utf-8") as kf:
                key = kf.read().strip()
            import hashlib
            import hmac
            replay_payload = json.dumps({"intent": "cell_heartbeat", "timestamp": int(time.time()), "nonce": hb_json["nonce"]})
            replay_sig = hmac.new(key.encode("utf-8"), replay_payload.encode("utf-8"), hashlib.sha256).hexdigest()
            rep = subprocess.run(["/bin/bash", wsu_path, "verify-ipc", replay_payload, replay_sig], env=env, capture_output=True, text=True)
            self.assertNotEqual(rep.returncode, 0)
            self.assertEqual(json.loads(rep.stdout.strip())["reason"], "replayed_nonce_detected")

            # 3. RDP RemoteApp uses /cert:tofu by default and /cert:fingerprint:sha256:<pin> when pinned
            app_default = json.loads(subprocess.run(["/bin/bash", wsu_path, "cell", "app", "||notepad"], env=env, capture_output=True, text=True, check=True).stdout)
            self.assertEqual(app_default["certVerification"], "/cert:tofu")
            pin_file = os.path.join(tmp, "wsu", "cell_rdp_sha256.pin")
            with open(pin_file, "w", encoding="utf-8") as pf:
                pf.write("AA:BB:CC:DD:EE:FF\n")
            app_pinned = json.loads(subprocess.run(["/bin/bash", wsu_path, "cell", "app", "||notepad"], env=env, capture_output=True, text=True, check=True).stdout)
            self.assertEqual(app_pinned["certVerification"], "/cert:fingerprint:sha256:AA:BB:CC:DD:EE:FF")

    def test_container_native_windows_dockur_spec_and_cli(self):
        import subprocess
        spec_path = os.path.join(ROOT, "distro", "CONTAINER_WINDOWS_V4_SPEC.md")
        compose_path = os.path.join(ROOT, "distro", "containers", "dockur-windows", "docker-compose.yml")
        oem_bat_path = os.path.join(ROOT, "distro", "containers", "dockur-windows", "oem", "install.bat")
        vm_cli = os.path.join(ROOT, "distro", "live-build", "config", "includes.chroot", "usr", "local", "bin", "stormraven-vm")
        for p in (spec_path, compose_path, oem_bat_path, vm_cli):
            self.assertTrue(os.path.isfile(p), f"Missing #98 artifact: {p}")
        with open(oem_bat_path, encoding="utf-8") as bf:
            bat_src = bf.read()
        self.assertIn("Get-FileHash", bat_src)
        self.assertIn("SHA256", bat_src)
        out = subprocess.run(["/bin/bash", vm_cli, "dockur-status"], capture_output=True, text=True, check=True)
        status_json = json.loads(out.stdout.strip())
        self.assertEqual(status_json["issue"], "#98")
        self.assertTrue(status_json["checksumVerifiedIsoRequired"])

    def test_incremental_iso_repack_builder_contract(self):
        import subprocess
        repack_sh = os.path.join(ROOT, "distro", "repack-ubuntu-iso.sh")
        self.assertTrue(os.path.isfile(repack_sh), "distro/repack-ubuntu-iso.sh must exist (#100)")
        with open(repack_sh, encoding="utf-8") as rf:
            rsrc = rf.read()
        self.assertIn("chmod 04755", rsrc)
        self.assertIn("NOPASSWD: ALL", rsrc)
        self.assertIn("PROVENANCE.json", rsrc)
        out = subprocess.run(["/bin/bash", repack_sh, "--dry-run"], capture_output=True, text=True, check=True)
        dry_json = json.loads(out.stdout.strip())
        self.assertEqual(dry_json["mode"], "incremental-layered-squashfs")
        self.assertIn("includesChrootSha256", dry_json["layers"])

    def test_continuous_runtime_attestation_engine_and_tamper_detection(self):
        import subprocess
        spec_path = os.path.join(ROOT, "docs", "RUNTIME_ATTESTATION_SPEC.md")
        attest_bin = os.path.join(
            ROOT, "distro", "live-build", "config", "includes.chroot", "usr", "local", "bin", "stormraven-attest"
        )
        self.assertTrue(os.path.isfile(spec_path))
        self.assertTrue(os.path.isfile(attest_bin))
        with tempfile.TemporaryDirectory() as tmp:
            bin_dir = os.path.join(tmp, "bin")
            os.makedirs(bin_dir, exist_ok=True)
            sample_bin = os.path.join(bin_dir, "stormraven-sample")
            with open(sample_bin, "w", encoding="utf-8") as sf:
                sf.write("#!/bin/sh\necho clean\n")
            env = os.environ.copy()
            env["STORMRAVEN_ATTEST_DIR"] = os.path.join(tmp, "state")
            env["STORMRAVEN_ATTEST_ROOT"] = bin_dir
            enroll_res = json.loads(
                subprocess.run(["python3", attest_bin, "enroll"], env=env, capture_output=True, text=True, check=True).stdout
            )
            self.assertTrue(enroll_res["ok"])
            self.assertEqual(enroll_res["binaryCount"], 1)

            scan_clean = json.loads(
                subprocess.run(["python3", attest_bin, "scan"], env=env, capture_output=True, text=True, check=True).stdout
            )
            self.assertEqual(scan_clean["verdict"], "CLEAN")
            self.assertTrue(scan_clean["manifestHmacValid"])
            self.assertEqual(scan_clean["verifiedBinaries"], 1)

            # Tamper with sample binary mid-session and confirm TAMPER_DETECTED
            with open(sample_bin, "w", encoding="utf-8") as sf:
                sf.write("#!/bin/sh\necho tampered\n")
            scan_tampered = json.loads(
                subprocess.run(["python3", attest_bin, "scan"], env=env, capture_output=True, text=True, check=True).stdout
            )
            self.assertEqual(scan_tampered["verdict"], "TAMPER_DETECTED")
            self.assertEqual(len(scan_tampered["driftedBinaries"]), 1)


if __name__ == "__main__":
    unittest.main()
