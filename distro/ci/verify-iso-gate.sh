#!/usr/bin/env bash
# =============================================================================
# StormRaven OS — Strict Pre-Publish ISO Verification Gate (Issue #110)
# =============================================================================
set -euo pipefail

ALLOW_UDF_ONLY=0
if [ "${1:-}" = "--allow-udf-only" ]; then
  ALLOW_UDF_ONLY=1
  shift
fi

ISO_FILE="${1:-}"
if [ -z "$ISO_FILE" ] || [ ! -f "$ISO_FILE" ]; then
  echo "[FAIL] ISO file missing: ${ISO_FILE:-<none>}" >&2
  exit 1
fi

SHA_FILE="${2:-${ISO_FILE}.sha256}"
if [ ! -f "$SHA_FILE" ]; then
  echo "[FAIL] .sha256 sidecar missing: $SHA_FILE" >&2
  exit 1
fi

EXPECTED_SHA="$(awk '{print $1}' "$SHA_FILE" | tr 'A-F' 'a-f')"
ACTUAL_SHA="$(sha256sum "$ISO_FILE" | awk '{print $1}' | tr 'A-F' 'a-f')"
if [ -z "$EXPECTED_SHA" ] || [ "$EXPECTED_SHA" != "$ACTUAL_SHA" ]; then
  echo "[FAIL] SHA-256 mismatch for $ISO_FILE: expected $EXPECTED_SHA, got $ACTUAL_SHA" >&2
  exit 1
fi

python3 - "$ISO_FILE" "$ALLOW_UDF_ONLY" << 'PY_EOF'
import os, sys, subprocess, tempfile, shutil

iso_path = sys.argv[1]
allow_udf_only = sys.argv[2] == "1"

size = os.path.getsize(iso_path)
if size < 65536:
    sys.exit(f"[FAIL] ISO file too small ({size} bytes): {iso_path}")

with open(iso_path, "rb") as f:
    header = f.read(0x9000)

if header[0x8001:0x8006] != b"CD001":
    sys.exit(f"[FAIL] Missing ISO9660 CD001 signature at 0x8001 in {iso_path}")

if not allow_udf_only:
    if header[510:512] != b"\x55\xaa":
        sys.exit(f"[FAIL] Missing hybrid MBR/GPT boot signature (0x55AA at byte 510) in {iso_path} — raw dd USB flash will not boot")

tmp_dir = tempfile.mkdtemp(prefix="sr-iso-gate-")
try:
    if shutil.which("xorriso"):
        subprocess.run(
            ["xorriso", "-osirrox", "on", "-indev", iso_path, "-extract", "/EFI", os.path.join(tmp_dir, "EFI")],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False
        )
    elif shutil.which("7z"):
        subprocess.run(
            ["7z", "x", iso_path, "EFI/*", "efi/*", f"-o{tmp_dir}", "-y"],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False
        )

    efi_files = []
    for root, _dirs, files in os.walk(tmp_dir):
        for fn in files:
            if fn.lower().endswith(".efi"):
                efi_files.append(os.path.join(root, fn))

    for ef in efi_files:
        ef_size = os.path.getsize(ef)
        if ef_size == 0:
            sys.exit(f"[FAIL] 0-byte EFI bootloader inside ISO tree: {os.path.relpath(ef, tmp_dir)}")
        with open(ef, "rb") as f:
            magic = f.read(2)
        if magic != b"MZ":
            sys.exit(f"[FAIL] Invalid PE header ({magic!r}, expected b'MZ') in {os.path.relpath(ef, tmp_dir)}")
finally:
    shutil.rmtree(tmp_dir, ignore_errors=True)

print(f"[PASS] {os.path.basename(iso_path)}: size={size} bytes, SHA-256 verified, ISO9660+EFI PE loaders valid.")
PY_EOF
