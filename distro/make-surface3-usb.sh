#!/usr/bin/env bash
# =============================================================================
# StormRaven OS v3.9.0 — Microsoft Surface 3 GPT + FAT32 Dual-EFI USB Builder
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
#   cd /tmp && curl -fsSLO https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/make-surface3-usb.sh && curl -fsSLO https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/make-surface3-usb.sh.sha256 && sha256sum -c make-surface3-usb.sh.sha256 && sudo bash make-surface3-usb.sh --verify-mode
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

TARGET_LABEL="${STORMRAVEN_TARGET_LABEL:-}"
TARGET_UUID="${STORMRAVEN_TARGET_UUID:-}"
USB_DEV=""
ISO_PATH=""
CONFIRM_FLAG="${STORMRAVEN_CONFIRM:-0}"

while [ $# -gt 0 ]; do
  case "$1" in
    --target-label)
      TARGET_LABEL="${2:-}"
      shift 2
      ;;
    --target-uuid)
      TARGET_UUID="${2:-}"
      shift 2
      ;;
    --yes|-y)
      CONFIRM_FLAG=1
      shift
      ;;
    *)
      if [ -z "${USB_DEV}" ]; then
        USB_DEV="$1"
      else
        ISO_PATH="$1"
      fi
      shift
      ;;
  esac
done

if [ -n "${TARGET_UUID}" ]; then
  PART_DEV="$(blkid -U "${TARGET_UUID}" 2>/dev/null || true)"
  if [ -z "${PART_DEV}" ] || [ ! -b "${PART_DEV}" ]; then
    echo "CRITICAL: Target UUID '${TARGET_UUID}' was not found on any attached block device. Failing closed." >&2
    exit 1
  fi
  PK="$(lsblk -no PKNAME "${PART_DEV}" 2>/dev/null | head -n 1 || true)"
  USB_DEV="${PK:+/dev/${PK}}"
  USB_DEV="${USB_DEV:-${PART_DEV}}"
elif [ -n "${TARGET_LABEL}" ]; then
  PART_DEV="$(blkid -L "${TARGET_LABEL}" 2>/dev/null || true)"
  if [ -z "${PART_DEV}" ] || [ ! -b "${PART_DEV}" ]; then
    echo "CRITICAL: Target LABEL '${TARGET_LABEL}' was not found on any attached block device. Failing closed." >&2
    exit 1
  fi
  PK="$(lsblk -no PKNAME "${PART_DEV}" 2>/dev/null | head -n 1 || true)"
  USB_DEV="${PK:+/dev/${PK}}"
  USB_DEV="${USB_DEV:-${PART_DEV}}"
fi

if [ -z "${USB_DEV}" ] || [ ! -b "${USB_DEV}" ]; then
  echo "CRITICAL: Target block device '${USB_DEV:-<none>}' was not found. Failing closed." >&2
  echo "Usage: sudo bash make-surface3-usb.sh [--target-label LABEL | --target-uuid UUID | /dev/sdX] [optional-path-to.iso]" >&2
  lsblk -d -o NAME,SIZE,MODEL,TRAN 2>/dev/null || true
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

if [ "${CONFIRM_FLAG}" != "1" ]; then
  printf "Type ERASE in capitals to confirm formatting %s as GPT+FAT32: " "${USB_DEV}"
  read -r USER_CONFIRM
  if [ "${USER_CONFIRM}" != "ERASE" ]; then
    echo "Cancelled. Nothing was written."
    exit 1
  fi
fi

BASE_URL="https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app"

echo "[STEP 1/3] Partitioning ${USB_DEV} as GPT + FAT32 (STORMRAVEN) for Surface 3 Class-3 UEFI"
sudo umount "${USB_DEV}"* 2>/dev/null || true
sudo parted -s "${USB_DEV}" mklabel gpt
sudo parted -s "${USB_DEV}" mkpart ESP fat32 1MiB 100%
sudo parted -s "${USB_DEV}" set 1 esp on
sudo parted -s "${USB_DEV}" set 1 boot on
PART="${USB_DEV}1"
[[ "${USB_DEV}" == *"nvme"* || "${USB_DEV}" == *"mmcblk"* ]] && PART="${USB_DEV}p1"
sleep 1
sudo mkfs.vfat -F 32 -n "STORMRAVEN" "${PART}"

MNT="/tmp/sr_surface3_usb"
sudo mkdir -p "${MNT}"
sudo mount "${PART}" "${MNT}"

if [ -n "${ISO_PATH}" ] && [ -f "${ISO_PATH}" ]; then
  echo "[STEP 2/3] Extracting ISO payload (${ISO_PATH}) onto ${PART}"
  sudo 7z x "${ISO_PATH}" -o"${MNT}" -y >/dev/null
else
  echo "[STEP 2/3] Skipping ISO extraction (no ISO path supplied; installing EFI bootpack only)"
fi

echo "[STEP 3/3] Installing dual BOOTX64.EFI + BOOTIA32.EFI bootloaders onto ${PART} (UUID=$(blkid -s UUID -o value "${PART}" 2>/dev/null || echo unknown))"
curl -fsSL "${BASE_URL}/Surface3-EFI-BootPack.zip" -o /tmp/Surface3-EFI-BootPack.zip
curl -fsSL "${BASE_URL}/Surface3-EFI-BootPack.zip.sha256" -o /tmp/Surface3-EFI-BootPack.zip.sha256
(cd /tmp && sha256sum -c Surface3-EFI-BootPack.zip.sha256)
sudo unzip -o /tmp/Surface3-EFI-BootPack.zip -d "${MNT}" >/dev/null
sync
sudo umount "${MNT}"
echo "================================================================"
echo "Surface 3 EFI Boot USB is READY on ${USB_DEV}!"
echo "1. Hold Volume-Up + tap Power -> Disable Secure Boot -> Save."
echo "2. Hold Volume-Down + tap Power -> release when Surface logo spins."
echo "================================================================"
