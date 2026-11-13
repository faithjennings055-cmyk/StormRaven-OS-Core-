#!/usr/bin/env bash
# StormRaven OS: Ymir Edition (v3.9.0) — Sovereign Key-Only SSH Hardening & iOS /sandbox Provisioning
# Founder: Dr. Justin Jennings ("Faith" / "Mr. Stormraven")
# Zero-Trust Standard: Works seamlessly in rootless iOS /sandbox shells AND full Ubuntu/Debian hosts.
set -euo pipefail

BASE_URL="https://echo-at-faith-s-workspace.skydive.app"
SSH_USER="${SUDO_USER:-${USER:-$(whoami 2>/dev/null || echo stormraven)}}"
USER_HOME="${HOME:-$(pwd)}"
if command -v getent >/dev/null 2>&1; then
  DETECTED_HOME="$(getent passwd "$SSH_USER" 2>/dev/null | cut -d: -f6 || true)"
  if [[ -n "$DETECTED_HOME" && -d "$DETECTED_HOME" && -w "$DETECTED_HOME" ]]; then
    USER_HOME="$DETECTED_HOME"
  fi
fi

SSH_DIR="$USER_HOME/.ssh"
BIN_DIR="$USER_HOME/bin"
FAITH_PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHMmx/Un999flE1aGZxsbWZlMddSCBaSkVNhPf2RIN96 faith@stormraven-sovereign"

echo "[StormRaven SSH] Provisioning Ed25519 SSH & StormRaven CLI in: $USER_HOME"

mkdir -p "$SSH_DIR" "$BIN_DIR"
export PATH="$BIN_DIR:$USER_HOME:$PATH"
chmod 700 "$SSH_DIR" 2>/dev/null || true
touch "$SSH_DIR/authorized_keys"
chmod 600 "$SSH_DIR/authorized_keys" 2>/dev/null || true

if ! grep -qF "AAAAC3NzaC1lZDI1NTE5AAAAIHMmx/Un999flE1aGZxsbWZlMddSCBaSkVNhPf2RIN96" "$SSH_DIR/authorized_keys" 2>/dev/null; then
  echo "$FAITH_PUBKEY" >> "$SSH_DIR/authorized_keys"
  echo "[StormRaven SSH] Added Faith's Ed25519 sovereign public key (SHA256:gtGGm+1oWtfzVdYbNKDZ0uH/yRoH8SO6BRQuRo91Lts)"
else
  echo "[StormRaven SSH] Faith's Ed25519 sovereign public key is already authorized."
fi

# Install pure-Python RFC 8032 Ed25519 ssh-keygen shim if native ssh-keygen is missing (e.g. iOS DevBox /sandbox $)
if ! command -v ssh-keygen >/dev/null 2>&1; then
  echo "[StormRaven SSH] Native ssh-keygen not found; installing pure-Python OpenSSH Ed25519 ssh-keygen..."
  curl -fsSL "$BASE_URL/ssh-keygen" -o "$BIN_DIR/ssh-keygen"
  chmod 755 "$BIN_DIR/ssh-keygen"
  cp "$BIN_DIR/ssh-keygen" "$USER_HOME/ssh-keygen" 2>/dev/null || true
  if [[ -w /usr/local/bin ]] 2>/dev/null; then
    cp "$BIN_DIR/ssh-keygen" /usr/local/bin/ssh-keygen 2>/dev/null || true
  fi
fi

if [[ ! -f "$SSH_DIR/id_ed25519" ]]; then
  if command -v ssh-keygen >/dev/null 2>&1; then
    ssh-keygen -t ed25519 -N "" -C "${SSH_USER}@$(hostname -s 2>/dev/null || echo ios-sandbox)-stormraven" -f "$SSH_DIR/id_ed25519" >/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    python3 "$BIN_DIR/ssh-keygen" -t ed25519 -N "" -C "${SSH_USER}@$(hostname -s 2>/dev/null || echo ios-sandbox)-stormraven" -f "$SSH_DIR/id_ed25519" >/dev/null
  fi
  if [[ -f "$SSH_DIR/id_ed25519.pub" ]]; then
    cat "$SSH_DIR/id_ed25519.pub" >> "$SSH_DIR/authorized_keys"
    chmod 600 "$SSH_DIR/id_ed25519" "$SSH_DIR/authorized_keys" 2>/dev/null || true
    echo "[StormRaven SSH] Generated local Ed25519 keypair at $SSH_DIR/id_ed25519"
  fi
fi

# Install portable 'sr' StormRaven CLI in USER_HOME for iOS /sandbox & Linux shells
cat << 'SR_EOF' > "$USER_HOME/sr"
#!/usr/bin/env bash
CMD="${1:-odin}"
curl -fsSL -X POST "https://echo-at-faith-s-workspace.skydive.app/terminal/exec" \
  -H "Content-Type: application/json" \
  -d "{\"command\":\"$CMD\"}"
echo ""
SR_EOF
chmod +x "$USER_HOME/sr" 2>/dev/null || true
cp "$USER_HOME/sr" "$BIN_DIR/sr" 2>/dev/null || true

for rc in "$USER_HOME/.profile" "$USER_HOME/.bashrc" "$USER_HOME/.ashrc" "$USER_HOME/.zshrc"; do
  touch "$rc" 2>/dev/null || true
  if ! grep -q 'HOME/bin' "$rc" 2>/dev/null; then
    printf '\nexport PATH="$HOME/bin:$HOME:$PATH"\n' >> "$rc" 2>/dev/null || true
  fi
done

# If running as root or with passwordless sudo on a full Linux host, also harden sshd
SUDO_CMD=""
if [[ "${EUID:-$(id -u 2>/dev/null || echo 1000)}" -eq 0 ]]; then
  SUDO_CMD=""
elif command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
  SUDO_CMD="sudo"
fi

if [[ "${EUID:-1000}" -eq 0 || -n "$SUDO_CMD" ]]; then
  if ! command -v sshd >/dev/null 2>&1 && command -v apt-get >/dev/null 2>&1; then
    $SUDO_CMD apt-get update -qq
    $SUDO_CMD apt-get install -y openssh-server
  fi

  if command -v sshd >/dev/null 2>&1; then
    $SUDO_CMD mkdir -p /etc/ssh/sshd_config.d
    $SUDO_CMD tee /etc/ssh/sshd_config.d/99-stormraven-sovereign.conf >/dev/null <<'SSHD'
# StormRaven OS: Ymir Edition — Zero-Trust Key-Only SSH Configuration
Port 2222
Port 22
Protocol 2
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication no
KbdInteractiveAuthentication no
ChallengeResponseAuthentication no
PermitEmptyPasswords no
PermitRootLogin no
X11Forwarding no
AllowTcpForwarding yes
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
SSHD
    $SUDO_CMD sshd -t 2>/dev/null || true
    $SUDO_CMD systemctl enable --now ssh 2>/dev/null || $SUDO_CMD systemctl enable --now sshd 2>/dev/null || true
    $SUDO_CMD systemctl reload ssh 2>/dev/null || $SUDO_CMD systemctl reload sshd 2>/dev/null || true
  fi

  if command -v ufw >/dev/null 2>&1; then
    $SUDO_CMD ufw allow 22/tcp >/dev/null 2>&1 || true
    $SUDO_CMD ufw allow 2222/tcp >/dev/null 2>&1 || true
  fi
fi

echo ""
echo "[StormRaven SSH] Sovereign Ed25519 keys, ssh-keygen & ~/sr CLI are ready."
echo "  Authorized Key : SHA256:gtGGm+1oWtfzVdYbNKDZ0uH/yRoH8SO6BRQuRo91Lts (faith@stormraven-sovereign)"
echo "  Run CLI        : $USER_HOME/sr status | $USER_HOME/sr odin | $USER_HOME/sr freya"
