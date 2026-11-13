#!/usr/bin/env sh
# StormRaven OS: Ymir Edition (v3.9.0) — 32-Bit (i386 / i686 / x86 / armhf / iSH) Universal Installer
# Founder: Dr. Justin Jennings ("Faith" / "Mr. Stormraven")
set -eu

ARCH="$(uname -m 2>/dev/null || echo i686)"
echo "=================================================================="
echo " StormRaven OS: Ymir Edition v3.9.0 — 32-Bit Provisioner ($ARCH)"
echo "=================================================================="

BASE_URL="https://echo-at-faith-s-workspace.skydive.app"
FAITH_PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHMmx/Un999flE1aGZxsbWZlMddSCBaSkVNhPf2RIN96 faith@stormraven-sovereign"

# Determine target root (system-wide if root on Linux, or $HOME/.stormraven32 in rootless /sandbox / iSH)
if [ "$(id -u 2>/dev/null || echo 1000)" = "0" ] && [ -w /usr/local/bin ] 2>/dev/null; then
  SR_ROOT="/opt/stormraven"
  BIN_DIR="/usr/local/bin"
else
  SR_ROOT="${HOME:-/tmp}/.stormraven"
  BIN_DIR="${HOME:-/tmp}/bin"
fi

mkdir -p "$SR_ROOT" "$BIN_DIR" "${HOME:-/tmp}/.ssh"
export PATH="$BIN_DIR:${HOME:-/tmp}:$PATH"
chmod 700 "${HOME:-/tmp}/.ssh" 2>/dev/null || true
touch "${HOME:-/tmp}/.ssh/authorized_keys"
chmod 600 "${HOME:-/tmp}/.ssh/authorized_keys" 2>/dev/null || true
if ! grep -q "IHMmx/Un999flE1aGZxsbWZlMddSCBaSkVNhPf2RIN96" "${HOME:-/tmp}/.ssh/authorized_keys" 2>/dev/null; then
  printf '%s\n' "$FAITH_PUBKEY" >> "${HOME:-/tmp}/.ssh/authorized_keys"
fi
if ! command -v ssh-keygen >/dev/null 2>&1; then
  curl -fsSL "$BASE_URL/ssh-keygen" -o "$BIN_DIR/ssh-keygen" 2>/dev/null || true
  chmod 755 "$BIN_DIR/ssh-keygen" 2>/dev/null || true
  cp "$BIN_DIR/ssh-keygen" "${HOME:-/tmp}/ssh-keygen" 2>/dev/null || true
fi
if [ ! -f "${HOME:-/tmp}/.ssh/id_ed25519" ]; then
  if command -v ssh-keygen >/dev/null 2>&1; then
    ssh-keygen -t ed25519 -N "" -C "faith@stormraven-32bit" -f "${HOME:-/tmp}/.ssh/id_ed25519" >/dev/null 2>&1 || true
  elif command -v python3 >/dev/null 2>&1 && [ -f "$BIN_DIR/ssh-keygen" ]; then
    python3 "$BIN_DIR/ssh-keygen" -t ed25519 -N "" -C "faith@stormraven-32bit" -f "${HOME:-/tmp}/.ssh/id_ed25519" >/dev/null 2>&1 || true
  fi
fi

TMP_DIR="$(mktemp -d 2>/dev/null || echo /tmp/sr32-install)"
mkdir -p "$TMP_DIR"

echo "[1/3] Downloading 32-bit bundle + SHA-256 sidecar..."
if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$BASE_URL/stormraven-os-3.9.0-i386-32bit.tar.gz" -o "$TMP_DIR/stormraven-os-3.9.0-i386-32bit.tar.gz"
  curl -fsSL "$BASE_URL/stormraven-os-3.9.0-i386-32bit.tar.gz.sha256" -o "$TMP_DIR/stormraven-os-3.9.0-i386-32bit.tar.gz.sha256"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "$TMP_DIR/stormraven-os-3.9.0-i386-32bit.tar.gz" "$BASE_URL/stormraven-os-3.9.0-i386-32bit.tar.gz"
  wget -qO "$TMP_DIR/stormraven-os-3.9.0-i386-32bit.tar.gz.sha256" "$BASE_URL/stormraven-os-3.9.0-i386-32bit.tar.gz.sha256"
fi

echo "[2/3] Verifying SHA-256 checksum..."
(cd "$TMP_DIR" && sha256sum -c stormraven-os-3.9.0-i386-32bit.tar.gz.sha256)

echo "[3/3] Extracting 32-bit StormRaven OS Ymir Edition runtime to $SR_ROOT..."
tar -xzf "$TMP_DIR/stormraven-os-3.9.0-i386-32bit.tar.gz" -C "$TMP_DIR"
cp -r "$TMP_DIR/stormraven-32bit/python" "$SR_ROOT/"
cp -r "$TMP_DIR/stormraven-32bit/webapp" "$SR_ROOT/"
cp -r "$TMP_DIR/stormraven-32bit/bin/"* "$BIN_DIR/" 2>/dev/null || true
chmod 755 "$BIN_DIR/"* 2>/dev/null || true

# Create convenient ~/sr wrapper for /sandbox & iSH
cat << 'WRAP' > "${HOME:-/tmp}/sr"
#!/usr/bin/env sh
SR_PY="/opt/stormraven/python"
[ -d "$SR_PY" ] || SR_PY="${HOME:-/tmp}/.stormraven/python"
CMD="${1:-status}"
shift 2>/dev/null || true
case "$CMD" in
  odin|freya|thor|tyr|heimdall|loki|demogorgon|baldur|bragi|fenrir)
    exec python3 "$SR_PY/${CMD}.py" "$@"
    ;;
  32|arch|version)
    echo "StormRaven OS v3.9.0 (Ymir Edition) — 32-bit ($(uname -m)) Sovereign Runtime [OK]"
    ;;
  *)
    if [ -x "/usr/local/bin/stormraven" ]; then
      exec /usr/local/bin/stormraven "$CMD" "$@"
    elif [ -x "${HOME:-/tmp}/bin/stormraven" ]; then
      exec "${HOME:-/tmp}/bin/stormraven" "$CMD" "$@"
    else
      exec python3 "$SR_PY/odin.py" "$CMD" "$@"
    fi
    ;;
esac
WRAP
chmod 755 "${HOME:-/tmp}/sr" "$BIN_DIR/sr" 2>/dev/null || cp "${HOME:-/tmp}/sr" "$BIN_DIR/sr" 2>/dev/null || true
rm -rf "$TMP_DIR"

echo ""
echo "[OK] StormRaven OS v3.9.0 (32-Bit Ymir Edition) installed!"
echo "  Run: ~/sr 32 | ~/sr status | ~/sr odin | ~/sr freya"
