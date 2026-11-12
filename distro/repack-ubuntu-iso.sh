#!/usr/bin/env bash
# =============================================================================
# StormRaven OS — Incremental / Layered SquashFS & ISO Baker (#100)
# =============================================================================
# Replaces full 25-minute debootstrap rebuilds with an incremental ~25-second
# layered bake:
#   1. Reuses the verified base squashfs (from BASE_ISO or cached rootfs layer)
#   2. Overlays changed files from:
#      - distro/live-build/config/includes.chroot/
#      - StormRaven.Python/ -> /opt/stormraven/python/
#      - distro/plymouth-theme/stormraven-void/
#      - distro/wallpapers/
#      - distro/grub-theme/stormraven/
#   3. Enforces the Compendium Hardening Matrix regression guard (#89):
#      - 04755 /usr/bin/sudo + /etc/sudoers.d/90-stormraven-live (NOPASSWD: ALL)
#   4. Repacks squashfs + hybrid BIOS/UEFI ISO, generates full-file .sha256
#      sidecar + per-layer hashes in distro/PROVENANCE.json (#95 / #100), and
#      mirrors artifacts to durable storage (${STORMRAVEN_ARTIFACT_MIRROR_DIR:-~/Documents}).
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
MIRROR_DIR="${STORMRAVEN_ARTIFACT_MIRROR_DIR:-${HOME:-/home/user}/Documents}"
WORK_DIR="${WORK_DIR:-/tmp/stormraven-incremental-repack}"

DEFAULT_BASE_ISO="/tmp/iso/StormRavenOS-Infinity-Protocol-v3.9.0-amd64.iso"
if [ ! -f "${DEFAULT_BASE_ISO}" ] && [ -f "${MIRROR_DIR}/StormRavenOS-Infinity-Protocol-v3.9.0-amd64.iso" ]; then
  mkdir -p /tmp/iso
  cp -f "${MIRROR_DIR}/StormRavenOS-Infinity-Protocol-v3.9.0-amd64.iso" "${DEFAULT_BASE_ISO}"
fi

BASE_ISO="${BASE_ISO:-${DEFAULT_BASE_ISO}}"
OUTPUT_ISO="${OUTPUT_ISO:-${DEFAULT_BASE_ISO}}"
DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --base-iso) BASE_ISO="$2"; shift 2 ;;
    --output-iso) OUTPUT_ISO="$2"; shift 2 ;;
    --dry-run|--status-json) DRY_RUN=1; shift ;;
    *) shift ;;
  esac
done

compute_tree_layer_hash() {
  local dir="$1"
  if [ ! -d "${dir}" ]; then
    echo "missing"
    return 0
  fi
  find "${dir}" -type f -print0 | sort -z | xargs -0 sha256sum | sha256sum | awk '{print $1}'
}

CHROOT_LAYER_SHA="$(compute_tree_layer_hash "${REPO_ROOT}/distro/live-build/config/includes.chroot")"
PYTHON_LAYER_SHA="$(compute_tree_layer_hash "${REPO_ROOT}/StormRaven.Python")"
WEBAPP_LAYER_SHA="$(compute_tree_layer_hash "${REPO_ROOT}/distro/live-build/config/includes.chroot/opt/stormraven/webapp")"
GRUB_LAYER_SHA="$(compute_tree_layer_hash "${REPO_ROOT}/distro/grub-theme/stormraven")"

if [ "${DRY_RUN}" = "1" ]; then
  cat <<JSON
{
  "builder": "distro/repack-ubuntu-iso.sh",
  "mode": "incremental-layered-squashfs",
  "baseIso": "${BASE_ISO}",
  "baseIsoExists": $( [ -f "${BASE_ISO}" ] && echo "true" || echo "false" ),
  "outputIso": "${OUTPUT_ISO}",
  "layers": {
    "includesChrootSha256": "${CHROOT_LAYER_SHA}",
    "pythonPantheonSha256": "${PYTHON_LAYER_SHA}",
    "webappHudSha256": "${WEBAPP_LAYER_SHA}",
    "grubThemeSha256": "${GRUB_LAYER_SHA}"
  }
}
JSON
  exit 0
fi

if [ ! -f "${BASE_ISO}" ]; then
  echo "ERROR: Base ISO not found at ${BASE_ISO}. Run distro/build-ubuntu-iso.sh once or provide --base-iso." >&2
  exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
else
  SUDO=""
fi

echo "==> [1/5] Extracting base ISO (${BASE_ISO}) into ${WORK_DIR}/iso..."
$SUDO rm -rf "${WORK_DIR}"
mkdir -p "${WORK_DIR}/iso" "$(dirname "${OUTPUT_ISO}")"
xorriso -osirrox on -indev "${BASE_ISO}" -extract / "${WORK_DIR}/iso" 2>/dev/null
$SUDO chmod -R u+w "${WORK_DIR}/iso"

SQUASH_SRC="${WORK_DIR}/iso/casper/stormraven-v393.squashfs"
if [ ! -f "${SQUASH_SRC}" ]; then
  SQUASH_SRC="${WORK_DIR}/iso/casper/filesystem.squashfs"
fi
BASE_SQUASH_SHA="$(sha256sum "${SQUASH_SRC}" | awk '{print $1}')"

echo "==> [2/5] Unsquashing base rootfs layer (${BASE_SQUASH_SHA:0:16}...)..."
$SUDO unsquashfs -d "${WORK_DIR}/rootfs" "${SQUASH_SRC}" >/dev/null

echo "==> [3/5] Applying incremental StormRaven OS layers (usrmerge-safe)..."
# Guard against top-level lib/ or bin/ clobbering Ubuntu 24.04/26.04 usrmerge symlinks
rm -rf "${REPO_ROOT}/distro/live-build/config/includes.chroot/lib"
$SUDO cp -a "${REPO_ROOT}/distro/live-build/config/includes.chroot/." "${WORK_DIR}/rootfs/"
$SUDO mkdir -p "${WORK_DIR}/rootfs/opt/stormraven/python" \
  "${WORK_DIR}/rootfs/usr/share/plymouth/themes/stormraven-void" \
  "${WORK_DIR}/rootfs/usr/share/backgrounds/stormraven"
$SUDO cp -a "${REPO_ROOT}/StormRaven.Python/." "${WORK_DIR}/rootfs/opt/stormraven/python/"
$SUDO cp -a "${REPO_ROOT}/distro/plymouth-theme/stormraven-void/." "${WORK_DIR}/rootfs/usr/share/plymouth/themes/stormraven-void/"
$SUDO cp -a "${REPO_ROOT}/distro/wallpapers/." "${WORK_DIR}/rootfs/usr/share/backgrounds/stormraven/"
$SUDO chmod +x "${WORK_DIR}/rootfs/usr/local/bin/"* 2>/dev/null || true

# Hard regression guard (#89): preserve 04755 /usr/bin/sudo and live passwordless sudoers
if [ -f "${WORK_DIR}/rootfs/usr/bin/sudo" ]; then
  $SUDO chown root:root "${WORK_DIR}/rootfs/usr/bin/sudo"
  $SUDO chmod 04755 "${WORK_DIR}/rootfs/usr/bin/sudo"
fi
$SUDO mkdir -p "${WORK_DIR}/rootfs/etc/sudoers.d"
$SUDO tee "${WORK_DIR}/rootfs/etc/sudoers.d/90-stormraven-live" >/dev/null <<'SUDOERS'
ubuntu ALL=(ALL) NOPASSWD: ALL
stormraven ALL=(ALL) NOPASSWD: ALL
%sudo ALL=(ALL) NOPASSWD: ALL
SUDOERS
$SUDO chmod 0440 "${WORK_DIR}/rootfs/etc/sudoers.d/90-stormraven-live"

mkdir -p "${WORK_DIR}/iso/boot/grub/themes"
cp -rf "${REPO_ROOT}/distro/grub-theme/stormraven" "${WORK_DIR}/iso/boot/grub/themes/"

echo "==> [4/5] Repacking layered squashfs & hybrid BIOS/UEFI ISO (${OUTPUT_ISO})..."
$SUDO rm -f "${WORK_DIR}/iso/casper/filesystem.squashfs" \
  "${WORK_DIR}/iso/casper/stormraven-v393.squashfs" \
  "${WORK_DIR}/iso/live/filesystem.squashfs"

STAMP="$(date -u +%Y%m%dT%H%MZ)"
echo "STORMRAVEN_V393_VERIFIED_${STAMP}" > "${WORK_DIR}/iso/casper/STORMRAVEN_V393.ID"
$SUDO mksquashfs "${WORK_DIR}/rootfs" "${WORK_DIR}/iso/casper/stormraven-v393.squashfs" \
  -comp zstd -Xcompression-level 15 -b 1M -processors 8 -noappend -e boot >/dev/null
NEW_SQUASH_SHA="$(sha256sum "${WORK_DIR}/iso/casper/stormraven-v393.squashfs" | awk '{print $1}')"

ln -sf stormraven-v393.squashfs "${WORK_DIR}/iso/casper/filesystem.squashfs"
mkdir -p "${WORK_DIR}/iso/live" "${WORK_DIR}/iso/.disk"
ln -sf ../casper/stormraven-v393.squashfs "${WORK_DIR}/iso/live/filesystem.squashfs"
echo "StormRaven OS 24.04/26.04 LTS - Infinity Protocol Incremental Layered Release amd64 (${STAMP})" > "${WORK_DIR}/iso/.disk/info"

grub-mkrescue -o "${OUTPUT_ISO}" "${WORK_DIR}/iso" -- -volid "STORMRAVEN_V393" 2>/dev/null
ISO_SHA="$(sha256sum "${OUTPUT_ISO}" | awk '{print $1}')"
echo "${ISO_SHA}  $(basename "${OUTPUT_ISO}")" > "${OUTPUT_ISO}.sha256"
$SUDO rm -rf "${WORK_DIR}"

echo "==> [5/5] Updating distro/PROVENANCE.json & mirroring to durable storage (${MIRROR_DIR})..."
if [ -d "${MIRROR_DIR}" ]; then
  cp -f "${OUTPUT_ISO}" "${OUTPUT_ISO}.sha256" "${MIRROR_DIR}/"
fi

if [ -f "${REPO_ROOT}/distro/PROVENANCE.json" ]; then
  python3 - "${REPO_ROOT}/distro/PROVENANCE.json" "${ISO_SHA}" "${BASE_SQUASH_SHA}" "${NEW_SQUASH_SHA}" "${CHROOT_LAYER_SHA}" "${PYTHON_LAYER_SHA}" "${WEBAPP_LAYER_SHA}" <<'PY'
import json, sys, time
prov_path, iso_sha, base_sq, new_sq, chroot_sha, py_sha, web_sha = sys.argv[1:8]
with open(prov_path, "r", encoding="utf-8") as f:
    data = json.load(f)
data["updatedUtc"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
u_iso = data.setdefault("artifacts", {}).setdefault("ubuntu2604Iso", {})
u_iso["infinityProtocolIsoSha256"] = iso_sha
u_iso["incrementalBake"] = {
    "builder": "distro/repack-ubuntu-iso.sh",
    "baseSquashfsSha256": base_sq,
    "repackedSquashfsSha256": new_sq,
    "layers": {
        "includesChrootSha256": chroot_sha,
        "pythonPantheonSha256": py_sha,
        "webappHudSha256": web_sha,
    },
}
with open(prov_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
fi

echo "==> Incremental bake complete: ${OUTPUT_ISO} (${ISO_SHA})"
