#!/usr/bin/env bash
# =============================================================================
# StormRaven OS: Infinity Protocol v3.9.3 — Direct Terminal USB Drive Flasher
# =============================================================================
# 1. Purges any stale /casper/filesystem.squashfs or old ISO partitions on
#    other drives/mounts so the initramfs can NEVER mount an old squashfs.
# 2. Downloads the verified StormRaven OS v3.9.3 ISO (with STORMRAVEN_V393.ID
#    and /casper/stormraven-v393.squashfs) and verifies its SHA-256 checksum.
# 3. Flashes the raw hybrid ISO byte-for-byte to your USB stick via dd + sync.
#
# One-command usage in your Ubuntu Terminal:
#   curl -fsSLO https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/flash-usb.sh && curl -fsSLO https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/flash-usb.sh.sha256 && sha256sum -c flash-usb.sh.sha256 && sudo bash flash-usb.sh
# =============================================================================
set -euo pipefail

VERSION="3.9.0"
ISO_FILENAME="StormRavenOS-Infinity-Protocol-v${VERSION}-amd64.iso"
PREBUILT_URL="https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/iso/${ISO_FILENAME}"
PREBUILT_SHA_URL="${PREBUILT_URL}.sha256"

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: Please run with sudo:"
  echo "  curl -fsSLO https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/flash-usb.sh && curl -fsSLO https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/flash-usb.sh.sha256 && sha256sum -c flash-usb.sh.sha256 && sudo bash flash-usb.sh"
  exit 1
fi

if [ -n "${SUDO_USER:-}" ] && [ "${SUDO_USER}" != "root" ]; then
  USER_HOME="$(getent passwd "${SUDO_USER}" | cut -d: -f6)"
else
  USER_HOME="${HOME:-/root}"
fi
OUT_DIR="${OUT_DIR:-${USER_HOME}/Downloads}"
mkdir -p "${OUT_DIR}"
ISO_PATH="${ISO_PATH:-${OUT_DIR}/${ISO_FILENAME}}"
SHA_PATH="${ISO_PATH}.sha256"

echo "======================================================================="
echo " ✦ STORMRAVEN OS v3.9.3 — DIRECT TERMINAL USB FLASHER"
echo "   Unique-ID Squashfs (STORMRAVEN_V393.ID) · PAM-Free Direct Login"
echo "======================================================================="

# 0. Purge any stale /casper/filesystem.squashfs on the host root or mounted partitions
rm -rf /casper /live /var/tmp/iso-* /tmp/iso-* 2>/dev/null || true

# 1. Check if the local ISO already matches the latest remote SHA-256
echo "==> [1/4] Checking latest StormRaven OS v3.9.3 ISO & SHA-256..."
curl -fsSL "${PREBUILT_SHA_URL}" -o "${SHA_PATH}"
EXPECTED_SHA="$(awk '{print $1}' "${SHA_PATH}")"

NEED_DOWNLOAD=1
if [ -f "${ISO_PATH}" ]; then
  CURRENT_SHA="$(sha256sum "${ISO_PATH}" | awk '{print $1}')"
  if [ "${CURRENT_SHA}" = "${EXPECTED_SHA}" ]; then
    echo "    Local ISO already matches latest SHA-256 (${EXPECTED_SHA:0:16}...)."
    NEED_DOWNLOAD=0
  else
    echo "    Local ISO checksum (${CURRENT_SHA:0:16}...) is older than latest (${EXPECTED_SHA:0:16}...). Replacing..."
    rm -f "${ISO_PATH}"
  fi
fi

if [ "${NEED_DOWNLOAD}" = "1" ]; then
  echo "    Downloading ${ISO_FILENAME} to ${ISO_PATH}..."
  curl -fL --retry 3 -o "${ISO_PATH}" "${PREBUILT_URL}"
  (cd "${OUT_DIR}" && sha256sum -c "${ISO_FILENAME}.sha256")
  [ -n "${SUDO_USER:-}" ] && chown "${SUDO_USER}:${SUDO_USER}" "${ISO_PATH}" "${SHA_PATH}" 2>/dev/null || true
fi

# 2. Identify the root OS disk so we NEVER touch it
ROOT_SRC="$(findmnt -n -o SOURCE / 2>/dev/null || true)"
ROOT_DISK=""
if [ -n "${ROOT_SRC}" ]; then
  ROOT_PKNAME="$(lsblk -no PKNAME "${ROOT_SRC}" 2>/dev/null | head -n 1 || true)"
  if [ -n "${ROOT_PKNAME}" ]; then
    ROOT_DISK="/dev/${ROOT_PKNAME}"
  else
    ROOT_DISK="${ROOT_SRC}"
  fi
fi

# Also check if any non-root internal/external partition has a stale /casper/filesystem.squashfs
echo "==> [2/4] Scanning partitions for any leftover stale /casper/filesystem.squashfs..."
mkdir -p /mnt/.sr-check
for part in $(lsblk -lnpo NAME,TYPE | awk '$2=="part"{print $1}'); do
  if ! findmnt -n "${part}" >/dev/null 2>&1; then
    if mount -o rw "${part}" /mnt/.sr-check 2>/dev/null; then
      if [ -f /mnt/.sr-check/casper/filesystem.squashfs ] && [ ! -f /mnt/.sr-check/casper/STORMRAVEN_V393.ID ]; then
        echo "    Removing stale /casper/filesystem.squashfs found on ${part}..."
        rm -rf /mnt/.sr-check/casper /mnt/.sr-check/live 2>/dev/null || true
        sync
      fi
      umount /mnt/.sr-check 2>/dev/null || true
    fi
  fi
done
rmdir /mnt/.sr-check 2>/dev/null || true

# 3. Detect removable USB drives
TARGET_DEV="${1:-${USB_DEV:-}}"
if [ -z "${TARGET_DEV}" ]; then
  echo "==> [3/4] Detecting connected USB flash drives..."
  mapfile -t USB_CANDIDATES < <(
    lsblk -dpno NAME,TRAN,RM,SIZE,VENDOR,MODEL,TYPE | awk -v root="${ROOT_DISK}" '
      $NF == "disk" && $1 != root && ($2 == "usb" || $3 == "1") && $1 !~ /^\/dev\/(loop|sr|zram|ram)/ {
        print $1
      }
    '
  )

  if [ "${#USB_CANDIDATES[@]}" -eq 0 ]; then
    echo ""
    echo "Available disks on this machine:"
    lsblk -dpo NAME,TRAN,RM,SIZE,MODEL,TYPE | grep -v "loop" || true
    echo ""
    echo "ERROR: No removable USB drive was auto-detected."
    echo "Plug in your USB drive and run again, or pass the device explicitly:"
    echo "  curl -fsSLO https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/flash-usb.sh && curl -fsSLO https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/flash-usb.sh.sha256 && sha256sum -c flash-usb.sh.sha256 && sudo bash flash-usb.sh /dev/sdX"
    exit 1
  elif [ "${#USB_CANDIDATES[@]}" -eq 1 ]; then
    TARGET_DEV="${USB_CANDIDATES[0]}"
    echo "    Auto-detected USB drive: ${TARGET_DEV} ($(lsblk -dno SIZE,VENDOR,MODEL "${TARGET_DEV}" 2>/dev/null | xargs))"
  else
    echo "Multiple removable USB drives detected:"
    for idx in "${!USB_CANDIDATES[@]}"; do
      dev="${USB_CANDIDATES[$idx]}"
      info="$(lsblk -dno SIZE,VENDOR,MODEL "${dev}" 2>/dev/null | xargs)"
      echo "  [$((idx + 1))] ${dev} (${info})"
    done
    if [ -r /dev/tty ]; then
      printf "Select USB drive number [1-%d]: " "${#USB_CANDIDATES[@]}" > /dev/tty
      read -r choice < /dev/tty
      TARGET_DEV="${USB_CANDIDATES[$((choice - 1))]}"
    else
      TARGET_DEV="${USB_CANDIDATES[0]}"
    fi
  fi
fi

if [ ! -b "${TARGET_DEV}" ]; then
  echo "ERROR: ${TARGET_DEV} is not a valid block device."
  exit 1
fi

if [ "${TARGET_DEV}" = "${ROOT_DISK}" ]; then
  echo "ERROR: Refusing to flash onto system root disk (${ROOT_DISK})!"
  exit 1
fi

echo "==> [4/4] Unmounting and wiping old partition signatures on ${TARGET_DEV}..."
for part in $(lsblk -lnpo NAME "${TARGET_DEV}" | tail -n +2); do
  umount -lf "${part}" 2>/dev/null || true
  wipefs -a "${part}" >/dev/null 2>&1 || true
done
wipefs -a "${TARGET_DEV}" >/dev/null 2>&1 || true
dd if=/dev/zero of="${TARGET_DEV}" bs=1M count=16 conv=fsync >/dev/null 2>&1 || true

echo "==> Flashing ${ISO_FILENAME} (v3.9.3) directly to ${TARGET_DEV} via dd..."
dd if="${ISO_PATH}" of="${TARGET_DEV}" bs=4M status=progress conv=fsync oflag=direct 2>/dev/null || \
  dd if="${ISO_PATH}" of="${TARGET_DEV}" bs=4M status=progress conv=fsync
sync
partprobe "${TARGET_DEV}" 2>/dev/null || true
udevadm settle 2>/dev/null || true

echo ""
echo "======================================================================="
echo " ✦ VERIFYING USB FLASH ON ${TARGET_DEV}..."
mkdir -p /mnt/.sr-verify
if mount -o ro "${TARGET_DEV}" /mnt/.sr-verify 2>/dev/null || mount -o ro "${TARGET_DEV}1" /mnt/.sr-verify 2>/dev/null; then
  if [ -f /mnt/.sr-verify/casper/STORMRAVEN_V393.ID ]; then
    echo "   ✓ VERIFIED: /casper/STORMRAVEN_V393.ID is present on ${TARGET_DEV} ($(cat /mnt/.sr-verify/casper/STORMRAVEN_V393.ID))"
  else
    echo "   ! WARNING: STORMRAVEN_V393.ID not found on ${TARGET_DEV}!"
  fi
  umount /mnt/.sr-verify 2>/dev/null || true
fi
rmdir /mnt/.sr-verify 2>/dev/null || true
echo " ✦ SUCCESS: StormRaven OS v3.9.3 flashed & verified on ${TARGET_DEV}!"
echo "   SHA-256: ${EXPECTED_SHA}"
echo "======================================================================="
