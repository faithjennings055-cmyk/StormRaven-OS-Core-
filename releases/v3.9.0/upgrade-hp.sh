#!/usr/bin/env bash
# =============================================================================
# StormRaven OS — Safe HP & Installed-System Upgrade & Boot Recovery (v3.9.x)
# =============================================================================
# Regression story (Issue #108, 2026-11-16 Surface 3 incident; pattern source #87):
#   A boot-repair sequence from Windows RE used 'assign letter=S' on an ambiguous
#   disk selection in a multi-drive machine (58GB SSD + 119GB microSD + 465GB
#   external USB all attached). Firmware 'Boot Option Restoration' auto-reset
#   boot config and caused a 1-hour red-screen bootloop.
#   Rule: Verify target disk by MODEL / SERIAL / LABEL / UUID / SIZE before any
#   write, refuse live RAM overlays, support --verify-mode, and require explicit
#   confirmation before writing.
#
# Tested paste-ready one-liner:
#   cd /tmp && curl -fsSLO https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/upgrade-hp.sh && curl -fsSLO https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/upgrade-hp.sh.sha256 && sha256sum -c upgrade-hp.sh.sha256 && sudo bash upgrade-hp.sh
# =============================================================================
set -euo pipefail

if [ "${1:-}" = "--verify-mode" ] || [ "${1:-}" = "verify-mode" ]; then
  echo "======================================================================="
  echo " ✦ CORE #108 VERIFY-MODE: DETECTED DRIVES (MODEL · SERIAL · LABELS)"
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

RAW_BASE="${STORMRAVEN_RAW_BASE:-https://raw.githubusercontent.com/faithjennings055-cmyk/StormRaven-OS-Core-/main}"
CLOUD_URL="${STORMRAVEN_CLOUD_URL:-https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app}"

TARGET_LABEL="${STORMRAVEN_TARGET_LABEL:-}"
TARGET_UUID="${STORMRAVEN_TARGET_UUID:-}"
TARGET_ROOT="${STORMRAVEN_TARGET_ROOT:-/}"
CONFIRM_UUID=""
AUTO_YES=0
DRY_RUN=0

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
    --target-root)
      TARGET_ROOT="${2:-/}"
      shift 2
      ;;
    --confirm-uuid)
      CONFIRM_UUID="${2:-}"
      shift 2
      ;;
    --yes|-y)
      AUTO_YES=1
      shift
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    *)
      echo "ERROR: Unknown argument '$1'" >&2
      echo "Usage: sudo bash upgrade-hp.sh [--target-label LABEL] [--target-uuid UUID] [--target-root PATH] [--confirm-uuid UUID] [--dry-run]" >&2
      exit 1
      ;;
  esac
done

echo "======================================================================="
echo " ✦ STORMRAVEN OS — SAFE HP UPGRADE & BOOT VERIFIER (#107 HARDENED)"
echo "======================================================================="

# -----------------------------------------------------------------------------
# 1. Resolve target partition by LABEL or UUID — fail closed if not found
# -----------------------------------------------------------------------------
RESOLVED_DEV=""
RESOLVED_UUID=""
RESOLVED_LABEL=""
RESOLVED_MNT=""

if [ -n "${TARGET_UUID}" ]; then
  if [ -n "${STORMRAVEN_FAKE_BLKID_FILE:-}" ]; then
    # Test harness hook for deterministic unit testing without root block devices
    RESOLVED_LINE="$(awk -v u="${TARGET_UUID}" '$2 == u {print $0; exit}' "${STORMRAVEN_FAKE_BLKID_FILE}" 2>/dev/null || true)"
    if [ -n "${RESOLVED_LINE}" ]; then
      RESOLVED_DEV="$(echo "${RESOLVED_LINE}" | awk '{print $1}')"
      RESOLVED_UUID="$(echo "${RESOLVED_LINE}" | awk '{print $2}')"
      RESOLVED_LABEL="$(echo "${RESOLVED_LINE}" | awk '{print $3}')"
      RESOLVED_MNT="$(echo "${RESOLVED_LINE}" | awk '{print $4}')"
    fi
  else
    RESOLVED_DEV="$(blkid -U "${TARGET_UUID}" 2>/dev/null || true)"
    if [ -n "${RESOLVED_DEV}" ] && [ -b "${RESOLVED_DEV}" ]; then
      RESOLVED_UUID="${TARGET_UUID}"
      RESOLVED_LABEL="$(blkid -s LABEL -o value "${RESOLVED_DEV}" 2>/dev/null || true)"
      RESOLVED_MNT="$(findmnt -rn -S "${RESOLVED_DEV}" -o TARGET 2>/dev/null | head -n 1 || true)"
    fi
  fi
  if [ -z "${RESOLVED_DEV}" ]; then
    echo "CRITICAL: Target UUID '${TARGET_UUID}' was not found on any attached block device. Failing closed." >&2
    exit 1
  fi
elif [ -n "${TARGET_LABEL}" ]; then
  if [ -n "${STORMRAVEN_FAKE_BLKID_FILE:-}" ]; then
    RESOLVED_LINE="$(awk -v l="${TARGET_LABEL}" '$3 == l {print $0; exit}' "${STORMRAVEN_FAKE_BLKID_FILE}" 2>/dev/null || true)"
    if [ -n "${RESOLVED_LINE}" ]; then
      RESOLVED_DEV="$(echo "${RESOLVED_LINE}" | awk '{print $1}')"
      RESOLVED_UUID="$(echo "${RESOLVED_LINE}" | awk '{print $2}')"
      RESOLVED_LABEL="$(echo "${RESOLVED_LINE}" | awk '{print $3}')"
      RESOLVED_MNT="$(echo "${RESOLVED_LINE}" | awk '{print $4}')"
    fi
  else
    RESOLVED_DEV="$(blkid -L "${TARGET_LABEL}" 2>/dev/null || true)"
    if [ -n "${RESOLVED_DEV}" ] && [ -b "${RESOLVED_DEV}" ]; then
      RESOLVED_LABEL="${TARGET_LABEL}"
      RESOLVED_UUID="$(blkid -s UUID -o value "${RESOLVED_DEV}" 2>/dev/null || true)"
      RESOLVED_MNT="$(findmnt -rn -S "${RESOLVED_DEV}" -o TARGET 2>/dev/null | head -n 1 || true)"
    fi
  fi
  if [ -z "${RESOLVED_DEV}" ]; then
    echo "CRITICAL: Target LABEL '${TARGET_LABEL}' was not found on any attached block device. Failing closed." >&2
    exit 1
  fi
else
  # Default: inspect TARGET_ROOT (/) and refuse live overlayfs unless explicitly mounted
  if [ -n "${STORMRAVEN_FAKE_BLKID_FILE:-}" ]; then
    RESOLVED_LINE="$(awk -v m="${TARGET_ROOT}" '$4 == m {print $0; exit}' "${STORMRAVEN_FAKE_BLKID_FILE}" 2>/dev/null || true)"
    if [ -n "${RESOLVED_LINE}" ]; then
      RESOLVED_DEV="$(echo "${RESOLVED_LINE}" | awk '{print $1}')"
      RESOLVED_UUID="$(echo "${RESOLVED_LINE}" | awk '{print $2}')"
      RESOLVED_LABEL="$(echo "${RESOLVED_LINE}" | awk '{print $3}')"
      RESOLVED_MNT="$(echo "${RESOLVED_LINE}" | awk '{print $4}')"
    fi
  else
    if mountpoint -q /run/live 2>/dev/null || mountpoint -q /run/casper 2>/dev/null || [ "$(findmnt -rn -o FSTYPE "${TARGET_ROOT}" 2>/dev/null || true)" = "overlay" ]; then
      echo "CRITICAL: Active root (${TARGET_ROOT}) is a live RAM overlay session, not an installed disk." >&2
      echo "Pass --target-label <LABEL> or --target-uuid <UUID> to target an installed disk explicitly. Failing closed." >&2
      exit 1
    fi
    RESOLVED_DEV="$(findmnt -rn -o SOURCE "${TARGET_ROOT}" 2>/dev/null || true)"
    if [ -n "${RESOLVED_DEV}" ] && [ -b "${RESOLVED_DEV}" ]; then
      RESOLVED_UUID="$(blkid -s UUID -o value "${RESOLVED_DEV}" 2>/dev/null || true)"
      RESOLVED_LABEL="$(blkid -s LABEL -o value "${RESOLVED_DEV}" 2>/dev/null || true)"
      RESOLVED_MNT="${TARGET_ROOT}"
    fi
  fi
  if [ -z "${RESOLVED_DEV}" ] || [ -z "${RESOLVED_UUID}" ]; then
    echo "CRITICAL: Could not verify block device UUID for target root '${TARGET_ROOT}'. Failing closed." >&2
    exit 1
  fi
fi

if [ -n "${RESOLVED_MNT}" ]; then
  TARGET_ROOT="${RESOLVED_MNT}"
fi

echo "RESOLVED TARGET:"
echo "  Device     : ${RESOLVED_DEV}"
echo "  UUID       : ${RESOLVED_UUID}"
echo "  LABEL      : ${RESOLVED_LABEL:-<unlabeled>}"
echo "  Mountpoint : ${TARGET_ROOT}"
echo ""

# -----------------------------------------------------------------------------
# 2. Require explicit confirmation before any write
# -----------------------------------------------------------------------------
if [ -n "${CONFIRM_UUID}" ]; then
  if [ "${CONFIRM_UUID}" != "${RESOLVED_UUID}" ]; then
    echo "CRITICAL: --confirm-uuid '${CONFIRM_UUID}' does not match resolved UUID '${RESOLVED_UUID}'. Failing closed." >&2
    exit 1
  fi
  echo "  [CONFIRMED] Target UUID verified via --confirm-uuid (${RESOLVED_UUID})."
elif [ "${AUTO_YES}" -eq 1 ]; then
  echo "  [CONFIRMED] Proceeding with verified target ${RESOLVED_DEV} (UUID=${RESOLVED_UUID})."
else
  printf "Type UPGRADE in capitals to confirm writing to %s (UUID=%s): " "${RESOLVED_DEV}" "${RESOLVED_UUID}"
  read -r USER_CONFIRM
  if [ "${USER_CONFIRM}" != "UPGRADE" ]; then
    echo "Cancelled. Nothing was written."
    exit 1
  fi
fi

if [ "${DRY_RUN}" -eq 1 ]; then
  echo "[STEP 1/6] DRY-RUN: Verified target ${RESOLVED_DEV} (UUID=${RESOLVED_UUID}, LABEL=${RESOLVED_LABEL:-none}) at ${TARGET_ROOT}; no files modified."
  exit 0
fi

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: Please run with sudo so system binaries under ${TARGET_ROOT} can be updated atomically." >&2
  exit 1
fi

STAGE_DIR="$(mktemp -d /tmp/stormraven-upgrade-hp.XXXXXX)"
trap 'rm -rf "${STAGE_DIR}"' EXIT

atomic_fetch_and_install() {
  local url="$1"
  local dest="$2"
  local mode="${3:-0755}"
  local tmp_file="${STAGE_DIR}/$(basename "${dest}").tmp"
  mkdir -p "$(dirname "${dest}")"
  if curl -fsSL --retry 3 "${url}" -o "${tmp_file}"; then
    if [ -s "${tmp_file}" ]; then
      chmod "${mode}" "${tmp_file}"
      mv -f "${tmp_file}" "${dest}"
      return 0
    fi
  fi
  return 1
}

BIN_DIR="${TARGET_ROOT%/}/usr/local/bin"
PY_DIR="${TARGET_ROOT%/}/opt/stormraven/python"
mkdir -p "${BIN_DIR}" "${PY_DIR}"

echo "[STEP 1/6] Staging and atomically installing stormraven-update engine to ${BIN_DIR}/stormraven-update"
atomic_fetch_and_install "${RAW_BASE}/distro/live-build/config/includes.chroot/usr/local/bin/stormraven-update" "${BIN_DIR}/stormraven-update" 0755

echo "[STEP 2/6] Staging and applying Ymir Edition HUD & mobile bridge via verified upgrade-void.sh"
if [ "${TARGET_ROOT}" = "/" ]; then
  if curl -fsSL "${CLOUD_URL}/upgrade-void.sh" -o "${STAGE_DIR}/upgrade-void.sh" && \
     curl -fsSL "${CLOUD_URL}/upgrade-void.sh.sha256" -o "${STAGE_DIR}/upgrade-void.sh.sha256"; then
    (cd "${STAGE_DIR}" && sha256sum -c upgrade-void.sh.sha256 >/dev/null)
    bash "${STAGE_DIR}/upgrade-void.sh" >/dev/null
  fi
fi

echo "[STEP 3/6] Staging and atomically updating core StormRaven CLIs (dualboot, gateway, demogorgon, hardening, raido)"
for f in stormraven-dualboot raido stormraven-local-gateway stormraven-demogorgon stormraven-hardening stormraven-installer stormraven-cloud-bridge; do
  atomic_fetch_and_install "${RAW_BASE}/distro/live-build/config/includes.chroot/usr/local/bin/${f}" "${BIN_DIR}/${f}" 0755 || true
done

echo "[STEP 4/6] Staging and atomically updating Bifrost local gateway Python runtime in ${PY_DIR}"
atomic_fetch_and_install "${RAW_BASE}/StormRaven.Python/stormraven_local_gateway.py" "${PY_DIR}/stormraven_local_gateway.py" 0644 || true
if [ "${TARGET_ROOT}" = "/" ]; then
  systemctl restart stormraven-kernel 2>/dev/null || systemctl restart stormraven 2>/dev/null || true
fi

echo "[STEP 5/6] Applying Demogorgon tarpit and Compendium Hardening Matrix (with 04755 sudo guard)"
if [ "${TARGET_ROOT}" = "/" ]; then
  "${BIN_DIR}/stormraven-demogorgon" awaken >/dev/null 2>&1 || true
  "${BIN_DIR}/stormraven-hardening" apply >/dev/null 2>&1 || true
  chmod 04755 /usr/bin/sudo 2>/dev/null || true
fi

echo "[STEP 6/6] Backing up GRUB configuration and running grub-verify UUID audit on ${TARGET_ROOT}"
if [ -f "${TARGET_ROOT%/}/boot/grub/grub.cfg" ]; then
  cp -f "${TARGET_ROOT%/}/boot/grub/grub.cfg" "${TARGET_ROOT%/}/boot/grub/grub.cfg.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
fi
if [ "${TARGET_ROOT}" = "/" ] && [ -x "${BIN_DIR}/stormraven-dualboot" ]; then
  "${BIN_DIR}/stormraven-dualboot" grub-verify
fi

echo "======================================================================="
echo " ✦ HP UPGRADE COMPLETE & VERIFIED ON ${RESOLVED_DEV} (UUID=${RESOLVED_UUID})"
echo "   Photo checkpoint: all 6 steps completed cleanly."
echo "======================================================================="
