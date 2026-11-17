#!/usr/bin/env bash
# =============================================================================
# StormRaven OS: Infinity Protocol v3.9.0 — Chromebook (Dev Mode + Crostini)
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
#   cd /tmp && curl -fsSLO https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/install-chromebook.sh && curl -fsSLO https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/install-chromebook.sh.sha256 && sha256sum -c install-chromebook.sh.sha256 && bash install-chromebook.sh
# =============================================================================
set -euo pipefail

BASE_URL="https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app"
MODE="${1:-both}"

if [ "${MODE}" = "--verify-mode" ] || [ "${MODE}" = "verify-mode" ]; then
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

echo "======================================================================="
echo " * STORMRAVEN OS v3.9.0 -- CHROMEBOOK (ZERO-PYTHON / ZERO-SUDO READY)"
echo "======================================================================="

IS_CHROMEOS_HOST=0
if [ -f /etc/lsb-release ] && grep -q "CHROMEOS_RELEASE" /etc/lsb-release 2>/dev/null; then
  IS_CHROMEOS_HOST=1
fi

# Helper: extract data.tar.* from a .deb using ONLY awk + dd + tar (no python3, no ar!)
extract_deb_to() {
  local DEB_FILE="$1"
  local DEST_DIR="$2"
  mkdir -p "$DEST_DIR"

  # Parse standard 60-byte ar headers using awk on byte offsets
  local INFO
  INFO="$(LC_ALL=C awk '
    BEGIN {
      pos = 8
    }
    {
      raw = raw $0 "\n"
    }
    END {
      # Remove trailing newline added by awk
      raw = substr(raw, 1, length(raw) - 1)
      len = length(raw)
      while (pos + 60 <= len) {
        hdr = substr(raw, pos + 1, 60)
        name = substr(hdr, 1, 16)
        gsub(/[ \/]+$/, "", name)
        sz_str = substr(hdr, 49, 10)
        gsub(/ /, "", sz_str)
        sz = sz_str + 0
        data_offset = pos + 60
        if (name ~ /^data\.tar/) {
          print name, data_offset, sz
          exit 0
        }
        pos = data_offset + sz + (sz % 2)
      }
    }
  ' "$DEB_FILE")"

  if [ -z "$INFO" ]; then
    echo "ERROR: Could not locate data.tar.* inside $DEB_FILE" >&2
    return 1
  fi

  local TAR_NAME OFFSET SIZE
  TAR_NAME="$(echo "$INFO" | awk '{print $1}')"
  OFFSET="$(echo "$INFO" | awk '{print $2}')"
  SIZE="$(echo "$INFO" | awk '{print $3}')"

  local TMP_TAR="/tmp/sr-${TAR_NAME}"
  rm -f "$TMP_TAR"
  dd if="$DEB_FILE" of="$TMP_TAR" bs=1 skip="$OFFSET" count="$SIZE" status=none 2>/dev/null || \
    tail -c +$((OFFSET + 1)) "$DEB_FILE" | head -c "$SIZE" > "$TMP_TAR"

  tar -xf "$TMP_TAR" -C "$DEST_DIR"
  rm -f "$TMP_TAR"
}

stage_usb_image() {
  local EDITION="${1:-gui}"
  if [ "$EDITION" = "console" ]; then
    ISO_NAME="StormRavenOS-Micro-v1.0-amd64.iso"
    BIN_NAME="StormRavenOS-Micro-v1.0-Surface3.bin"
  else
    ISO_NAME="StormRavenOS-Infinity-Micro-GUI-v3.9.0-amd64.iso"
    BIN_NAME="StormRavenOS-Infinity-Micro-GUI-v3.9.0-Surface3.bin"
  fi

  OUT_DIR="/tmp"
  if [ -d "/home/chronos/user/Downloads" ]; then
    OUT_DIR="/home/chronos/user/Downloads"
  elif [ -d "/mnt/chromeos/MyFiles/Downloads" ]; then
    OUT_DIR="/mnt/chromeos/MyFiles/Downloads"
  fi

  echo "==> [2/3] Downloading & verifying $ISO_NAME in $OUT_DIR ..."
  cd "$OUT_DIR"
  curl -fsSL -o "$ISO_NAME.sha256" "$BASE_URL/iso/$ISO_NAME.sha256"
  EXPECTED_SHA="$(awk '{print $1}' "$ISO_NAME.sha256")"

  NEED_DL=1
  if [ -f "$ISO_NAME" ]; then
    ACTUAL_SHA="$(sha256sum "$ISO_NAME" | awk '{print $1}')"
    if [ "$ACTUAL_SHA" = "$EXPECTED_SHA" ]; then
      echo "    [OK] Cached $ISO_NAME matches SHA-256 ($ACTUAL_SHA)"
      NEED_DL=0
    fi
  fi

  if [ "$NEED_DL" -eq 1 ]; then
    curl -fL --retry 3 -o "$ISO_NAME" "$BASE_URL/iso/$ISO_NAME"
  fi
  sha256sum -c "$ISO_NAME.sha256"
  cp -f "$ISO_NAME" "$BIN_NAME" 2>/dev/null || true

  echo ""
  echo "==> [3/3] Attached storage devices (Core #108 hardware check):"
  lsblk -d -o NAME,SIZE,MODEL,SERIAL,TRAN,RM 2>/dev/null | sed 's/^/    /' || lsblk -d -o NAME,SIZE,MODEL,TRAN,RM | sed 's/^/    /'
  echo ""
}

install_on_chromebook() {
  CAN_SUDO=0
  SUDO_CMD=""
  if [ "$(id -u)" -eq 0 ]; then
    CAN_SUDO=1
  elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
    CAN_SUDO=1
    SUDO_CMD="sudo"
  fi

  if [ "$CAN_SUDO" -eq 1 ] && [ -w /usr/local ]; then
    DEST_ROOT="/usr/local/stormraven"
    BIN_DEST="/usr/local/bin"
    $SUDO_CMD mkdir -p "$BIN_DEST" "$DEST_ROOT" /tmp/stormraven-void
  else
    echo "    [i] Running unprivileged (crosh no_new_privs) -- installing into $HOME/stormraven"
    DEST_ROOT="$HOME/stormraven/root"
    BIN_DEST="$HOME/.local/bin"
    mkdir -p "$BIN_DEST" "$DEST_ROOT" "$HOME/stormraven" /tmp/stormraven-void
  fi

  echo "==> [1/3] Downloading & verifying stormraven-os_3.9.0_amd64.deb..."
  cd /tmp
  curl -fsSL "$BASE_URL/iso/stormraven-os_3.9.0_amd64.deb" -o stormraven-os.deb
  curl -fsSL "$BASE_URL/iso/stormraven-os_3.9.0_amd64.deb.sha256" -o stormraven-os.deb.sha256
  sed -i 's|stormraven-os_3.9.0_amd64.deb|stormraven-os.deb|g' stormraven-os.deb.sha256
  sha256sum -c stormraven-os.deb.sha256

  echo "    Extracting .deb with pure awk+tar unpacker (zero python3 / zero ar required)..."
  extract_deb_to /tmp/stormraven-os.deb "$DEST_ROOT"
  cp -rf "$DEST_ROOT/usr/local/bin/"* "$BIN_DEST/" 2>/dev/null || true
  cp -rf "$DEST_ROOT/usr/bin/"* "$BIN_DEST/" 2>/dev/null || true

  # Write pure-Bash StormRaven CLI (`stormraven` & `freya`) that works even when python3 is absent
  cat > "$BIN_DEST/stormraven" <<'SRCLI'
#!/usr/bin/env bash
BASE_URL="https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app"
CMD="${1:-status}"
shift 2>/dev/null || true
case "$CMD" in
  status)
    echo "=========================================================="
    echo " STORMRAVEN OS : INFINITY PROTOCOL v3.9.0 (Chromebook)"
    echo "=========================================================="
    echo " Host     : $(hostname 2>/dev/null || uname -n)"
    echo " Kernel   : $(uname -srm)"
    echo " Memory   : $(free -h 2>/dev/null | awk '/^Mem:/{print $3" used / "$2" total ("$7" free)"}')"
    echo " Cloud HUD: $BASE_URL/hud"
    echo "----------------------------------------------------------"
    curl -fsSL "$BASE_URL/api/status" 2>/dev/null && echo "" || true
    echo "=========================================================="
    ;;
  ai|freya|think)
    PROMPT="${*:-status}"
    curl -fsSL -X POST "$BASE_URL/api/freya/chat" \
      -H "Content-Type: application/json" \
      -d "{\"message\":\"$PROMPT\"}" 2>/dev/null || \
    curl -fsSL -X POST "$BASE_URL/api/command" \
      -H "Content-Type: application/json" \
      -d "{\"command\":\"odin_freya_think\"}" 2>/dev/null
    echo ""
    ;;
  realms)
    echo "=========================================================="
    echo " YGGDRASIL : THE NINE REALMS & ODIN PANTHEON"
    echo "=========================================================="
    printf " %-14s %-10s %s\n" "Asgard"       "[ONLINE]"  "Freya Cortana-Class Sovereign AI"
    printf " %-14s %-10s %s\n" "Midgard"      "[ONLINE]"  "Bifrost Gateway & SSH Mesh"
    printf " %-14s %-10s %s\n" "Heimdall"     "[ARMED]"   "Zero-Trust CWE-77 Allow-List"
    printf " %-14s %-10s %s\n" "Alfheim"      "[ONLINE]"  "Chromebook & Surface 3 HUD"
    printf " %-14s %-10s %s\n" "Vanaheim"     "[ONLINE]"  "Vitality & TPM 2.0 Sensor Matrix"
    printf " %-14s %-10s %s\n" "Jotunheim"    "[ONLINE]"  "Deep Archive & Luci Key Ledger"
    printf " %-14s %-10s %s\n" "Svartalfheim" "[ONLINE]"  "Binary Forge & Kernel Stack"
    printf " %-14s %-10s %s\n" "Niflheim"     "[ONLINE]"  "SquashFS Zstd Live Snapshot"
    printf " %-14s %-10s %s\n" "Helheim"      "[ARMED]"   "Demogorgon Tarpit & Isolation Vault"
    echo "=========================================================="
    ;;
  ssh)
    bash "$HOME/.stormraven-os/bin/sr-ssh" 2>/dev/null || curl -fsSL "$BASE_URL/api/ssh/mesh"
    echo ""
    ;;
  *)
    curl -fsSL -X POST "$BASE_URL/api/command" \
      -H "Content-Type: application/json" \
      -d "{\"command\":\"$CMD\"}" 2>/dev/null
    echo ""
    ;;
esac
SRCLI
  chmod 0755 "$BIN_DEST/stormraven" 2>/dev/null || true
  cp -f "$BIN_DEST/stormraven" "$HOME/sr" 2>/dev/null || true
  cp -f "$BIN_DEST/stormraven" "$BIN_DEST/freya" 2>/dev/null || true

  for rc in "$HOME/.bashrc" "$HOME/.profile"; do
    touch "$rc" 2>/dev/null || true
    if ! grep -q ".local/bin" "$rc" 2>/dev/null; then
      echo 'export PATH="$HOME/.local/bin:$HOME/.stormraven-os/bin:$PATH"' >> "$rc"
    fi
  done
  export PATH="$BIN_DEST:$HOME/.stormraven-os/bin:$PATH"

  # Set up SSH keypair + Mesh registration (zero python3 / zero sudo required)
  curl -fsSLO "$BASE_URL/setup-ssh.sh"
  curl -fsSLO "$BASE_URL/setup-ssh.sh.sha256"
  sha256sum -c setup-ssh.sh.sha256
  bash setup-ssh.sh || true
}

if [ "$MODE" = "flash" ] || [ "$MODE" = "usb" ] || [ "$MODE" = "iso" ]; then
  TARGET_DEV="${2:-}"
  EDITION="${3:-gui}"
  if [ "$TARGET_DEV" = "console" ] || [ "$TARGET_DEV" = "gui" ]; then
    EDITION="$TARGET_DEV"
    TARGET_DEV="${3:-}"
  fi

  stage_usb_image "$EDITION"

  if [ -z "$TARGET_DEV" ]; then
    echo "Image staged at: $OUT_DIR/$BIN_NAME"
    echo "Open 'Chromebook Recovery Utility' -> Gear icon -> 'Use local image' -> pick '$BIN_NAME'."
    exit 0
  fi

  if [ ! -b "$TARGET_DEV" ]; then
    echo "ERROR: $TARGET_DEV is not a block device." >&2
    exit 1
  fi
  ROOT_DISK="$(rootdev -s -d 2>/dev/null || echo "")"
  if [ -n "$ROOT_DISK" ] && [ "$TARGET_DEV" = "$ROOT_DISK" ]; then
    echo "ABORT: $TARGET_DEV is the Chromebook's internal OS drive ($ROOT_DISK)!" >&2
    exit 1
  fi
  case "$TARGET_DEV" in
    /dev/mmcblk0*|/dev/nvme0n1*|/dev/loop*|/dev/zram*)
      echo "ABORT: Refusing to overwrite internal/loop storage ($TARGET_DEV)." >&2
      exit 1
      ;;
  esac

  echo "======================================================================="
  echo " * CORE #108 TARGET VERIFICATION BEFORE WRITE:"
  echo "======================================================================="
  lsblk -d -o NAME,SIZE,MODEL,SERIAL,TRAN,RM "$TARGET_DEV" 2>/dev/null || lsblk -d -o NAME,SIZE,MODEL,TRAN,RM "$TARGET_DEV"
  echo ""
  printf "Type ERASE in all caps to overwrite %s (anything else cancels): " "$TARGET_DEV"
  read -r CONFIRM </dev/tty
  if [ "$CONFIRM" != "ERASE" ]; then
    echo "Cancelled. Nothing was written."
    exit 0
  fi

  for p in "${TARGET_DEV}"*; do
    umount "$p" 2>/dev/null || sudo umount "$p" 2>/dev/null || true
  done

  ISO_FILE="$OUT_DIR/$ISO_NAME"
  echo "==> Writing $ISO_FILE to $TARGET_DEV ..."
  dd if="$ISO_FILE" of="$TARGET_DEV" bs=4M conv=fsync status=progress 2>/dev/null || \
    sudo dd if="$ISO_FILE" of="$TARGET_DEV" bs=4M conv=fsync status=progress
  sync
  echo "==> [OK] $TARGET_DEV flashed and synced."
  exit 0
fi

install_on_chromebook
stage_usb_image "gui"

echo "======================================================================="
echo " * BOTH COMPLETE: CHROMEBOOK LIVE + USB IMAGE STAGED"
echo "======================================================================="
echo "  - Run StormRaven CLI : bash ~/sr status"
echo "  - Talk to Freya AI   : bash ~/sr freya \"status\""
echo "  - Nine Realms Matrix : bash ~/sr realms"
echo "  - SSH Mesh Nodes     : bash ~/sr ssh"
echo "  - USB Image Staged   : /home/chronos/user/Downloads/$BIN_NAME"
echo "    (Open Chromebook Recovery Utility -> Gear icon -> Use local image)"
echo "======================================================================="
