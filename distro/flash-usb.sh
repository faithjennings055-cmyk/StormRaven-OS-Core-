#!/usr/bin/env bash
# =============================================================================
# StormRaven OS: Infinity Protocol v3.9.0 — Direct Terminal USB Drive Flasher
# =============================================================================
# Bypasses Ubuntu Startup Disk Creator so the verified hybrid MBR/GPT/UEFI ISO,
# initrd, and squashfs are written byte-for-byte directly to your USB stick.
#
# One-command usage in your Ubuntu Terminal:
#   curl -fsSL https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/flash-usb.sh | sudo bash
#
# Or specify your USB device explicitly (e.g. /dev/sdb):
#   curl -fsSL https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/flash-usb.sh | sudo bash -s -- /dev/sdb
# =============================================================================
set -euo pipefail

VERSION="3.9.0"
ISO_FILENAME="StormRavenOS-Infinity-Protocol-v${VERSION}-amd64.iso"
PREBUILT_URL="https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/iso/${ISO_FILENAME}"
PREBUILT_SHA_URL="${PREBUILT_URL}.sha256"

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: Please run with sudo:"
  echo "  curl -fsSL https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/flash-usb.sh | sudo bash"
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
echo " ✦ STORMRAVEN OS v${VERSION} — DIRECT TERMINAL USB FLASHER"
echo "   Bypasses Ubuntu Startup Disk Creator (byte-for-byte raw dd flash)"
echo "======================================================================="

# 1. Check if the local ISO already matches the latest remote SHA-256
echo "==> [1/4] Checking latest StormRaven OS v${VERSION} ISO & SHA-256..."
curl -fsSL "${PREBUILT_SHA_URL}" -o "${SHA_PATH}"
EXPECTED_SHA="$(awk '{print $1}' "${SHA_PATH}")"

NEED_DOWNLOAD=1
if [ -f "${ISO_PATH}" ]; then
  CURRENT_SHA="$(sha256sum "${ISO_PATH}" | awk '{print $1}')"
  if [ "${CURRENT_SHA}" = "${EXPECTED_SHA}" ]; then
    echo "    Local ISO already matches latest SHA-256 (${EXPECTED_SHA:0:16}...)."
    NEED_DOWNLOAD=0
  else
    echo "    Local ISO checksum (${CURRENT_SHA:0:16}...) is older than latest (${EXPECTED_SHA:0:16}...). Updating..."
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

# 3. Detect removable USB drives
TARGET_DEV="${1:-${USB_DEV:-}}"
if [ -z "${TARGET_DEV}" ]; then
  echo ""
  echo "==> [2/4] Detecting connected USB flash drives..."
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
    echo "  curl -fsSL https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/flash-usb.sh | sudo bash -s -- /dev/sdX"
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
      echo "Please re-run and pass the target USB device explicitly, e.g.:"
      echo "  curl -fsSL https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/flash-usb.sh | sudo bash -s -- ${USB_CANDIDATES[0]}"
      exit 1
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

echo ""
echo "==> [3/4] Unmounting any mounted partitions on ${TARGET_DEV}..."
for part in $(lsblk -lnpo NAME "${TARGET_DEV}" | tail -n +2); do
  umount -lf "${part}" 2>/dev/null || true
done
wipefs -a "${TARGET_DEV}" >/dev/null 2>&1 || true

echo "==> [4/4] Flashing ${ISO_FILENAME} directly to ${TARGET_DEV} via dd..."
dd if="${ISO_PATH}" of="${TARGET_DEV}" bs=4M status=progress conv=fsync oflag=direct 2>/dev/null || \
  dd if="${ISO_PATH}" of="${TARGET_DEV}" bs=4M status=progress conv=fsync
sync
partprobe "${TARGET_DEV}" 2>/dev/null || true
udevadm settle 2>/dev/null || true

echo ""
echo "======================================================================="
echo " ✦ SUCCESS: StormRaven OS v${VERSION} flashed directly to ${TARGET_DEV}!"
echo "   SHA-256: ${EXPECTED_SHA}"
echo "   You can now reboot and boot directly from ${TARGET_DEV}."
echo "======================================================================="
