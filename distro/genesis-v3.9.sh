#!/usr/bin/env bash
# =============================================================================
# StormRaven OS: Infinity Protocol v3.9.0 — Automated Genesis ISO & Package Suite
# =============================================================================
# Usage (run on Ubuntu Desktop):
#   curl -fsSL https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/genesis-v3.9.sh | sudo bash
#
# Or install as a Debian package (.deb) or Ubuntu Snap (.snap):
#   curl -fsSLO https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/iso/stormraven-os_3.9.0_amd64.deb
#   sudo dpkg -i stormraven-os_3.9.0_amd64.deb
#
#   curl -fsSLO https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/iso/stormraven-os_3.9.0_amd64.snap
#   sudo snap install --dangerous --classic stormraven-os_3.9.0_amd64.snap
# =============================================================================
set -euo pipefail

VERSION="3.9.0"
ISO_FILENAME="StormRavenOS-Infinity-Protocol-v${VERSION}-amd64.iso"
REPO_URL="https://github.com/faithjennings055-cmyk/StormRaven-OS-Core-.git"
PREBUILT_URL="https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/iso/${ISO_FILENAME}"
PREBUILT_SHA_URL="${PREBUILT_URL}.sha256"

if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
  USER_HOME="$(getent passwd "${SUDO_USER}" | cut -d: -f6)"
else
  USER_HOME="${HOME:-/root}"
fi
OUT_DIR="${OUT_DIR:-${USER_HOME}/Downloads}"
mkdir -p "${OUT_DIR}"
OUTPUT_ISO="${OUTPUT_ISO:-${OUT_DIR}/${ISO_FILENAME}}"

echo "======================================================================="
echo " ✦ STORMRAVEN OS: INFINITY PROTOCOL v${VERSION} — GENESIS AUTOMATION"
echo "   Kernel: Linux 7.0.0-42-generic HWE · 2011-2026 Firmware & Drivers"
echo "   Boot Mode: Try or Install + Full Ubuntu Boot Disk Rescue Suite"
echo "======================================================================="
echo " Target ISO: ${OUTPUT_ISO}"
echo ""

# Clean up any leftover /tmp RAM-disk build directories from earlier runs so /tmp is never full
for mp in dev/pts dev proc sys run; do
  umount -lf "/tmp/stormraven-ubuntu-build/chroot/${mp}" 2>/dev/null || true
done
rm -rf /tmp/stormraven-ubuntu-build /tmp/stormraven-genesis-src 2>/dev/null || true

# Remove any old/duplicate StormRaven ISOs in the output folder so only v3.9.0 remains
rm -f "${OUT_DIR}"/StormRavenOS-ubuntu-24.04-amd64.iso* \
      "${OUT_DIR}"/StormRavenOS-v3.6-amd64.iso* \
      "${OUT_DIR}"/StormRavenOS-Infinity-Protocol-v3.7.0-amd64.iso* \
      "${OUT_DIR}"/StormRavenOS-Infinity-Protocol-v3.8.0-amd64.iso* 2>/dev/null || true

if [ "${FORCE_LOCAL_BUILD:-0}" != "1" ]; then
  echo "==> [Genesis 1/3] Fetching verified StormRaven OS v${VERSION} ISO..."
  if curl -fL --retry 3 -o "${OUTPUT_ISO}" "${PREBUILT_URL}" && \
     curl -fsSL -o "${OUTPUT_ISO}.sha256" "${PREBUILT_SHA_URL}"; then
    echo "==> [Genesis 2/3] Verifying SHA-256 integrity..."
    (cd "${OUT_DIR}" && sha256sum -c "${ISO_FILENAME}.sha256")
    [ -n "${SUDO_USER:-}" ] && chown "${SUDO_USER}:${SUDO_USER}" "${OUTPUT_ISO}" "${OUTPUT_ISO}.sha256" 2>/dev/null || true
    echo "==> [Genesis 3/3] StormRaven OS v${VERSION} ISO ready at:"
    echo "    ${OUTPUT_ISO}"
    if command -v usb-creator-gtk >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
      echo "==> Launching Ubuntu Startup Disk Creator with ${OUTPUT_ISO}..."
      sudo -u "${SUDO_USER:-$(whoami)}" usb-creator-gtk -i "${OUTPUT_ISO}" >/dev/null 2>&1 &
    fi
    exit 0
  fi
  echo "==> Prebuilt download unavailable, falling back to full local Genesis build..."
fi

echo "==> [Genesis 1/4] Installing Ubuntu ISO build dependencies..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq \
  git curl ca-certificates debootstrap squashfs-tools xorriso \
  grub-pc-bin grub-efi-amd64-bin mtools dosfstools

WORK_REPO="/var/tmp/stormraven-genesis-src"
rm -rf "${WORK_REPO}"
echo "==> [Genesis 2/4] Cloning StormRaven-OS-Core- into /var/tmp (disk-backed)..."
git clone --depth 1 "${REPO_URL}" "${WORK_REPO}"

echo "==> [Genesis 3/4] Running full Ubuntu 24.04 LTS (Noble) v${VERSION} ISO build in /var/tmp..."
WORK_DIR="/var/tmp/stormraven-ubuntu-build" OUTPUT_ISO="${OUTPUT_ISO}" CLEAN_BUILD=1 bash "${WORK_REPO}/distro/build-ubuntu-iso.sh"

[ -n "${SUDO_USER:-}" ] && chown "${SUDO_USER}:${SUDO_USER}" "${OUTPUT_ISO}" "${OUTPUT_ISO}.sha256" 2>/dev/null || true
rm -rf "${WORK_REPO}" "/var/tmp/stormraven-ubuntu-build"

echo "======================================================================="
echo " ✦ GENESIS COMPLETE: ${OUTPUT_ISO}"
echo "======================================================================="
if command -v usb-creator-gtk >/dev/null 2>&1 && [ -n "${DISPLAY:-}" ]; then
  echo "==> Launching Ubuntu Startup Disk Creator..."
  sudo -u "${SUDO_USER:-$(whoami)}" usb-creator-gtk -i "${OUTPUT_ISO}" >/dev/null 2>&1 &
fi
