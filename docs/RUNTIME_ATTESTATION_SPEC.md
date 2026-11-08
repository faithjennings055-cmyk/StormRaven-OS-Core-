# StormRaven OS: Continuous Runtime Binary Attestation Specification (Issue #101)

## 1. Objective & Zero-Trust Threat Model

Boot-time secure measurements (UEFI Secure Boot + SHA-256 ISO/SquashFS provenance verification via `distro/PROVENANCE.json` `#95`) verify integrity at boot, but do not detect **mid-session binary tampering**, memory-backed binary replacement (`memfd_create` / `/tmp` execution), or unauthorized modifications to `/usr/local/bin/stormraven*` and `/opt/stormraven/python/*.py` while the system is running.

Issue `#101` adds a **Continuous Runtime Binary Attestation** subsystem (`stormraven-attest`) that continuously measures both on-disk binaries and active process executable images (`/proc/<pid>/exe`) against a signed SHA-256 baseline manifest.

---

## 2. Architecture & Scoping Matrix

### 2.1 What Is Measured
1. **Tier-0 Sovereign Binaries & Daemons (`/usr/local/bin/stormraven*`, `/usr/local/bin/freya`, `/usr/local/bin/cortana`, `/usr/local/bin/wsu`):**
   - Full SHA-256 digest of every script and ELF executable in the StormRaven command surface.
2. **Tier-1 Pantheon Python Modules (`/opt/stormraven/python/*.py`):**
   - Full SHA-256 digest of `odin.py`, `freya.py`, `heimdall.py`, `loki.py`, `lynn.py`, `luci.py`, `solomon.py`, `heketa.py`, `thor.py`, `bifrost.py`, `deadman.py`, `ragnarok.py`.
3. **Tier-2 Active Process Images (`/proc/<pid>/exe` & `/proc/<pid>/cmdline`):**
   - For every running process matching `stormraven-*`, `freya`, `odin`, or listening on Sovereign ports (`:3887`, `:8787`, `:2222`), `stormraven-attest` resolves `/proc/<pid>/exe`, detects `(deleted)` unlink replacement or `/tmp`/`/dev/shm`/`memfd:` execution, and hashes the underlying binary image.
4. **Tier-3 Linux IMA (Integrity Measurement Architecture) Hook:**
   - When `/sys/kernel/security/ima/ascii_runtime_measurements` is mounted by the kernel, `stormraven-attest` reads kernel IMA measurement counts and surfaces any `invalid-hash` appraisal violations.

### 2.2 Cadence & Performance Cost on Real Hardware
- **Hash Throughput:** Hashing all ~45 StormRaven CLI binaries + 15 Python modules (~1.4 MB total bytes) using hardware-accelerated SHA-256 (`hashlib.sha256` / OpenSSL SHA-NI) takes **< 4.5 milliseconds** of wall-clock time and **< 0.02% CPU** when sampled every 30 seconds.
- **Default Interval:** `STORMRAVEN_ATTEST_INTERVAL_SEC=30` (configurable; one-shot `stormraven-attest scan` runs on-demand or from the Security War Room `#99`).
- **Memory Footprint:** Stateless one-shot scan or ~12 MB resident RSS in continuous daemon mode (`--watch`).

### 2.3 False-Positive Handling & Legitimate Upgrade Window
A naive runtime attestation daemon will trigger false positives during legitimate `stormraven-update` (`raido`) runs or `dpkg`/`apt` package upgrades. `stormraven-attest` prevents false positives via three rules:
1. **Signed Maintenance Lock (`/run/stormraven-update.lock`):** When `stormraven-update` applies a verified update, it holds a short-lived lock and invokes `stormraven-attest enroll` immediately after verifying the incoming package `.sha256` sidecar.
2. **Interpreter Resolution (`python3` / `bash`):** Because Python and Bash scripts execute under `/usr/bin/python3` or `/usr/bin/bash` in `/proc/<pid>/exe`, `stormraven-attest` inspects both `/proc/<pid>/exe` (verifying the system interpreter is not `(deleted)` or running from `/tmp`) AND `argv[1]` (hashing the target script against the enrolled baseline).
3. **Gated Feature Flag (`STORMRAVEN_ATTEST_ENFORCE`):**
   - `audit` (default POC mode): logs any drift or tampering event to Loki (`loki.py` JSONL + SQLite incident ledger) and raises a `CRITICAL` Security War Room decision (`sr.rule.attest.runtime.v1`) without killing the user's desktop session.
   - `enforce` (strict mode): immediately quarantines the tampered PID (`SIGSTOP` -> Helheim cgroup isolation) and revokes its Bifrost IPC token.

---

## 3. CLI & Gateway Contract (`stormraven-attest`)

```bash
# Enroll / refresh baseline manifest (HMAC-SHA256 sealed with per-install Luci.key)
stormraven-attest enroll

# Run an immediate runtime attestation scan (JSON output)
stormraven-attest scan

# Check current attestation posture & baseline summary
stormraven-attest status
```
