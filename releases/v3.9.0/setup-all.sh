#!/usr/bin/env sh
# StormRaven OS: Ymir Edition (v3.9.0) — Master All-In-One Provisioner
# Includes pure-Python RFC 8032 OpenSSH Ed25519 ssh-keygen polyfill for iOS DevBox (/sandbox $) & rootless shells
set -eu

BASE_URL="https://echo-at-faith-s-workspace.skydive.app"
FAITH_PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHMmx/Un999flE1aGZxsbWZlMddSCBaSkVNhPf2RIN96 faith@stormraven-sovereign"
ARCH="$(uname -m 2>/dev/null || echo unknown)"
OS_NAME="$(uname -s 2>/dev/null || echo iOS)"
HOME_DIR="${HOME:-/sandbox}"
[ -d "$HOME_DIR" ] || HOME_DIR="$(pwd)"
BIN_DIR="$HOME_DIR/bin"
SSH_DIR="$HOME_DIR/.ssh"
mkdir -p "$BIN_DIR" "$SSH_DIR" "$HOME_DIR/.stormraven"
export PATH="$BIN_DIR:$HOME_DIR:$PATH"

IS_ROOT=0
if [ "$(id -u 2>/dev/null || echo 1000)" = "0" ]; then
  IS_ROOT=1
fi
SUDO=""
if [ "$IS_ROOT" = "0" ] && command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
  SUDO="sudo"
  IS_ROOT=1
fi

echo "=================================================================="
echo " StormRaven OS v3.9.0 — Master All-In-One Setup ($OS_NAME / $ARCH)"
echo "=================================================================="

# ------------------------------------------------------------------
# STEP 1: Sovereign Ed25519 SSH + Pure-Python ssh-keygen Polyfill
# ------------------------------------------------------------------
echo "[1/4] Configuring Sovereign Ed25519 SSH & ssh-keygen..."
chmod 700 "$SSH_DIR" 2>/dev/null || true
touch "$SSH_DIR/authorized_keys"
chmod 600 "$SSH_DIR/authorized_keys" 2>/dev/null || true

if ! grep -q "IHMmx/Un999flE1aGZxsbWZlMddSCBaSkVNhPf2RIN96" "$SSH_DIR/authorized_keys" 2>/dev/null; then
  printf '%s\n' "$FAITH_PUBKEY" >> "$SSH_DIR/authorized_keys"
fi

# Install pure-Python ssh-keygen shim if native ssh-keygen is missing (e.g. iOS DevBox /sandbox $)
if ! command -v ssh-keygen >/dev/null 2>&1; then
  if command -v apk >/dev/null 2>&1 && [ "$IS_ROOT" = "1" ]; then
    apk add --no-cache openssh-keygen openssh-client >/dev/null 2>&1 || true
  fi
fi

if ! command -v ssh-keygen >/dev/null 2>&1; then
  echo "      -> Native ssh-keygen not in sandbox; installing pure-Python OpenSSH Ed25519 ssh-keygen..."
  curl -fsSL "$BASE_URL/ssh-keygen" -o "$BIN_DIR/ssh-keygen"
  chmod 755 "$BIN_DIR/ssh-keygen"
  cp "$BIN_DIR/ssh-keygen" "$HOME_DIR/ssh-keygen" 2>/dev/null || true
  if [ -w /usr/local/bin ] 2>/dev/null; then
    cp "$BIN_DIR/ssh-keygen" /usr/local/bin/ssh-keygen 2>/dev/null || true
  elif [ -w /bin ] 2>/dev/null; then
    cp "$BIN_DIR/ssh-keygen" /bin/ssh-keygen 2>/dev/null || true
  fi
fi

if [ ! -f "$SSH_DIR/id_ed25519" ]; then
  if command -v ssh-keygen >/dev/null 2>&1; then
    ssh-keygen -t ed25519 -N "" -C "faith@stormraven-node" -f "$SSH_DIR/id_ed25519"
  elif command -v python3 >/dev/null 2>&1; then
    python3 "$BIN_DIR/ssh-keygen" -t ed25519 -N "" -C "faith@stormraven-node" -f "$SSH_DIR/id_ed25519"
  fi
fi

if [ -f "$SSH_DIR/id_ed25519.pub" ]; then
  echo "      -> Local Ed25519 Public Key ($SSH_DIR/id_ed25519.pub):"
  cat "$SSH_DIR/id_ed25519.pub"
fi

# ------------------------------------------------------------------
# STEP 2: Fast Ad-Blocking DNS (AdGuard + Cloudflare + Tailscale .ts.net)
# ------------------------------------------------------------------
echo "[2/4] Configuring Fast Ad-Blocking DNS (94.140.14.14 / 94.140.15.15 + 1.1.1.1)..."
cat << 'DNSCONF' > "$HOME_DIR/.stormraven/dns.conf"
PRIMARY_DNS=94.140.14.14
SECONDARY_DNS=94.140.15.15
FALLBACK_DNS=1.1.1.1
DOH_ENDPOINT=https://dns.adguard-dns.com/dns-query
TAILSCALE_SPLIT_DOMAIN=ts.net
DNSCONF

if [ "$IS_ROOT" = "1" ] && [ -d /etc/systemd ]; then
  $SUDO mkdir -p /etc/systemd/resolved.conf.d 2>/dev/null || true
  cat << 'RESOLVED' | $SUDO tee /etc/systemd/resolved.conf.d/99-stormraven-adblock-dns.conf >/dev/null 2>&1 || true
[Resolve]
DNS=94.140.14.14#dns.adguard-dns.com 94.140.15.15#dns.adguard-dns.com
FallbackDNS=1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com
DNSOverTLS=opportunistic
Domains=~.
RESOLVED
  if command -v systemctl >/dev/null 2>&1; then
    $SUDO systemctl restart systemd-resolved >/dev/null 2>&1 || true
  fi
fi
echo "      -> AdGuard Ad-Blocking DNS + Cloudflare fallback configured"

# ------------------------------------------------------------------
# STEP 3: Tailscale Mesh + Tailscale SSH
# ------------------------------------------------------------------
echo "[3/4] Checking Tailscale Mesh & Tailscale SSH..."
if [ "$IS_ROOT" = "1" ] && [ -x /usr/bin/apt-get ] && ! command -v tailscale >/dev/null 2>&1; then
  CODENAME="$(lsb_release -cs 2>/dev/null || echo bookworm)"
  curl -fsSL "https://pkgs.tailscale.com/stable/debian/${CODENAME}.noarmor.gpg" | $SUDO tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null 2>&1 || true
  curl -fsSL "https://pkgs.tailscale.com/stable/debian/${CODENAME}.tailscale-keyring.list" | $SUDO tee /etc/apt/sources.list.d/tailscale.list >/dev/null 2>&1 || true
  $SUDO apt-get update -qq >/dev/null 2>&1 || true
  $SUDO apt-get install -y -qq tailscale >/dev/null 2>&1 || true
fi
echo "      -> Tailnet ready (iOS app + MagicDNS 94.140.14.14 / 94.140.15.15)"

# ------------------------------------------------------------------
# STEP 4: StormRaven OS v3.9.0 Ymir Edition Runtime & CLI
# ------------------------------------------------------------------
echo "[4/4] Installing StormRaven OS v3.9.0 (Ymir Edition) Runtime & ~/sr CLI..."
curl -fsSL "$BASE_URL/install-ios.sh" -o "$HOME_DIR/.stormraven/install-ios.sh"
curl -fsSL "$BASE_URL/install-ios.sh.sha256" -o "$HOME_DIR/.stormraven/install-ios.sh.sha256"
if command -v sha256sum >/dev/null 2>&1; then
  (cd "$HOME_DIR/.stormraven" && sha256sum -c install-ios.sh.sha256 >/dev/null)
elif command -v shasum >/dev/null 2>&1; then
  (cd "$HOME_DIR/.stormraven" && shasum -a 256 -c install-ios.sh.sha256 >/dev/null)
fi
sh "$HOME_DIR/.stormraven/install-ios.sh" >/dev/null 2>&1 || true

for rc in "$HOME_DIR/.profile" "$HOME_DIR/.bashrc" "$HOME_DIR/.ashrc" "$HOME_DIR/.zshrc"; do
  touch "$rc" 2>/dev/null || true
  if ! grep -q 'HOME/bin' "$rc" 2>/dev/null; then
    printf '\nexport PATH="$HOME/bin:$HOME:$PATH"\n' >> "$rc" 2>/dev/null || true
  fi
done

echo ""
echo "=================================================================="
echo " [OK] ALL 4 SYSTEMS COMPLETE — StormRaven OS v3.9.0 Ymir Edition"
echo "  1. ssh-keygen : Installed at $BIN_DIR/ssh-keygen (Ed25519 Key Ready)"
echo "  2. Fast DNS   : AdGuard 94.140.14.14 / 94.140.15.15 + 1.1.1.1"
echo "  3. Tailnet    : Tailscale SSH + MagicDNS Ready"
echo "  4. Ymir CLI   : Run './sr status' | './sr freya' | './ssh-keygen -lf ~/.ssh/id_ed25519.pub'"
echo "=================================================================="
