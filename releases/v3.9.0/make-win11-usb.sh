#!/usr/bin/env bash
# =============================================================================
# StormRaven OS — Windows 11 Ymir Edition GPT/UEFI Bootable USB Creator
# =============================================================================
# Regression story (Issue #108, 2026-11-16 Surface 3 incident; pattern source #87):
#   A boot-repair sequence from Windows RE used 'assign letter=S' on an ambiguous
#   disk selection in a multi-drive machine (58GB SSD + 119GB microSD + 465GB
#   external USB all attached). Firmware 'Boot Option Restoration' auto-reset
#   boot config and caused a 1-hour red-screen bootloop.
#   Rule: Verify target disk by MODEL / SERIAL / LABEL / UUID / SIZE before any
#   write, refuse internal OS drives (/dev/mmcblk0*, /dev/nvme0n1*, /dev/loop*,
#   /dev/zram*, rootdev -s -d), support --verify-mode, and require typing ERASE.
#
# Tested paste-ready one-liner:
#   cd /tmp && curl -fsSLO https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/make-win11-usb.sh && curl -fsSLO https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/make-win11-usb.sh.sha256 && sha256sum -c make-win11-usb.sh.sha256 && sudo bash make-win11-usb.sh --verify-mode
# =============================================================================
set -euo pipefail

if [ "${1:-}" = "--verify-mode" ] || [ "${1:-}" = "verify-mode" ]; then
  echo "======================================================================="
  echo " * CORE #108 VERIFY-MODE: DETECTED DRIVES (MODEL · SERIAL · LABELS)"
  echo "======================================================================="
  if [ -n "${STORMRAVEN_FAKE_LSBLK_FILE:-}" ] && [ -f "${STORMRAVEN_FAKE_LSBLK_FILE}" ]; then
    cat "${STORMRAVEN_FAKE_LSBLK_FILE}"
  else
    lsblk -d -o NAME,SIZE,MODEL,SERIAL,TRAN,RM,TYPE 2>/dev/null || lsblk -d -o NAME,SIZE,MODEL,TRAN,RM
    echo ""
    lsblk -o NAME,SIZE,FSTYPE,LABEL,UUID,MOUNTPOINT 2>/dev/null || true
  fi
  printf "Enter the SERIAL (or exact LABEL) of the target drive to verify: "
  read -r WANTED_SERIAL
  if [ -z "${WANTED_SERIAL}" ]; then
    echo "CRITICAL: Empty serial/label entered. Failing closed." >&2
    exit 1
  fi
  MATCHED_DEV=""
  if [ -n "${STORMRAVEN_FAKE_LSBLK_FILE:-}" ] && [ -f "${STORMRAVEN_FAKE_LSBLK_FILE}" ]; then
    MATCHED_DEV="$(awk -v s="${WANTED_SERIAL}" 'NR>1 && ($4 == s || $3 == s) {print "/dev/"$1; exit}' "${STORMRAVEN_FAKE_LSBLK_FILE}" 2>/dev/null || true)"
  else
    MATCHED_DEV="$(lsblk -dpno NAME,SERIAL,LABEL 2>/dev/null | awk -v s="${WANTED_SERIAL}" '$2 == s || $3 == s {print $1; exit}' || true)"
  fi
  if [ -z "${MATCHED_DEV}" ]; then
    echo "CRITICAL: No attached drive matches serial/label '${WANTED_SERIAL}'. Failing closed." >&2
    exit 1
  fi
  echo "RESOLVED TARGET:"
  echo "  Device         : ${MATCHED_DEV}"
  echo "  Matched Serial : ${WANTED_SERIAL}"
  exit 0
fi

WIN_ISO="${1:-}"
USB_DEV="${2:-}"

if [ -z "${WIN_ISO}" ] || [ -z "${USB_DEV}" ]; then
  echo "Usage: sudo bash make-win11-usb.sh <path-to-StormRavenOS-Win11-Ymir.iso> <usb-device e.g. /dev/sdb>"
  echo ""
  echo "Available disks:"
  lsblk -d -o NAME,SIZE,MODEL,SERIAL,TRAN,RM 2>/dev/null | grep -v loop || lsblk -d -o NAME,SIZE,MODEL,TRAN | grep -v loop || true
  exit 1
fi

if [ ! -f "${WIN_ISO}" ]; then
  echo "Error: ISO file not found: ${WIN_ISO}" >&2
  exit 1
fi

if [ ! -b "${USB_DEV}" ]; then
  echo "Error: Block device not found: ${USB_DEV}" >&2
  exit 1
fi

ROOT_SRC="$(findmnt -n -o SOURCE / 2>/dev/null || true)"
CHROME_ROOT="$(rootdev -s -d 2>/dev/null || echo "")"
if { [ -n "${ROOT_SRC}" ] && [[ "${ROOT_SRC}" == "${USB_DEV}"* ]]; } || \
   { [ -n "${CHROME_ROOT}" ] && [ "${USB_DEV}" = "${CHROME_ROOT}" ]; }; then
  echo "CRITICAL: ${USB_DEV} is the active root drive (${ROOT_SRC:-${CHROME_ROOT}}). Failing closed." >&2
  exit 1
fi
case "${USB_DEV}" in
  /dev/mmcblk0*|/dev/nvme0n1*|/dev/loop*|/dev/zram*)
    echo "CRITICAL: Refusing to overwrite protected internal/virtual block device (${USB_DEV}). Failing closed." >&2
    exit 1
    ;;
esac

echo "RESOLVED TARGET:"
echo "  Device : ${USB_DEV}"
lsblk -d -o NAME,SIZE,MODEL,SERIAL,TRAN,RM "${USB_DEV}" 2>/dev/null || lsblk -d -o NAME,SIZE,MODEL,TRAN,RM "${USB_DEV}" 2>/dev/null || true
echo "  Labels : $(lsblk -lnpo LABEL,UUID "${USB_DEV}" 2>/dev/null | xargs || echo none)"
echo ""
if [ "${STORMRAVEN_CONFIRM:-0}" != "1" ]; then
  printf "Type ERASE in all caps to confirm formatting %s for Windows 11 USB: " "${USB_DEV}"
  read -r USER_CONFIRM
  if [ "${USER_CONFIRM}" != "ERASE" ]; then
    echo "Cancelled. Nothing was written."
    exit 1
  fi
fi

echo "==> Preparing GPT + UEFI FAT32/NTFS layout on ${USB_DEV} for ${WIN_ISO}..."
umount "${USB_DEV}"* 2>/dev/null || true
wipefs -a "${USB_DEV}"

parted -s "${USB_DEV}" mklabel gpt
parted -s "${USB_DEV}" mkpart ESP fat32 1MiB 1537MiB
parted -s "${USB_DEV}" set 1 esp on
parted -s "${USB_DEV}" mkpart primary ntfs 1537MiB 100%
partprobe "${USB_DEV}" || true
sleep 2

if [[ "${USB_DEV}" == *nvme* ]] || [[ "${USB_DEV}" == *mmcblk* ]]; then
  P1="${USB_DEV}p1"
  P2="${USB_DEV}p2"
else
  P1="${USB_DEV}1"
  P2="${USB_DEV}2"
fi

mkfs.vfat -F 32 -n "SR_UEFI" "${P1}"
mkfs.ntfs -f -L "SR_WIN11" "${P2}"

MNT_ISO="$(mktemp -d /tmp/sr-winiso.XXXXXX)"
MNT_ESP="$(mktemp -d /tmp/sr-esp.XXXXXX)"
MNT_NTFS="$(mktemp -d /tmp/sr-ntfs.XXXXXX)"
trap 'umount "$MNT_ISO" "$MNT_ESP" "$MNT_NTFS" 2>/dev/null || true; rmdir "$MNT_ISO" "$MNT_ESP" "$MNT_NTFS" 2>/dev/null || true' EXIT

mount -o loop,ro "${WIN_ISO}" "${MNT_ISO}"
mount "${P1}" "${MNT_ESP}"
mount "${P2}" "${MNT_NTFS}"

echo "==> Copying UEFI bootloader and Windows Preinstallation Environment (boot.wim) to FAT32 ESP..."
mkdir -p "${MNT_ESP}/sources"
cp -r "${MNT_ISO}/efi" "${MNT_ESP}/" 2>/dev/null || true
cp -r "${MNT_ISO}/EFI" "${MNT_ESP}/" 2>/dev/null || true
cp -r "${MNT_ISO}/boot" "${MNT_ESP}/" 2>/dev/null || true
cp -f "${MNT_ISO}/bootmgr"* "${MNT_ESP}/" 2>/dev/null || true
cp -f "${MNT_ISO}/sources/boot.wim" "${MNT_ESP}/sources/boot.wim"
cp -f "${MNT_ISO}/autounattend.xml" "${MNT_ESP}/" 2>/dev/null || true

echo "==> Copying full Windows 11 Ymir Edition installation payload to NTFS partition..."
cp -rf "${MNT_ISO}/." "${MNT_NTFS}/"
sync

echo "==> Done! ${USB_DEV} is now a UEFI-bootable Windows 11 Ymir Edition drive (no 0xc000000f)."
