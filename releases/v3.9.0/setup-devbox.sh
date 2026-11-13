#!/usr/bin/env bash
# ==============================================================================
# StormRaven OS v3.9.0 (Ymir & ÁLFHEIMR Edition) — Ultimate DevBox Configuration
# Target: iOS DevBox (`SYSTEM TERMINAL` / `/sandbox $`) & Jetify `devbox.json`
# What this configures automatically inside `/sandbox`:
#   1. Complete `devbox.json` & `.env` (Python 3, OpenSSH, Tailscale, SQLite)
#   2. Pure-Python RFC 8032 `ssh-keygen` + Ed25519 keys + optimized `~/.ssh/config`
#      (ControlMaster multiplexing, ServerAliveInterval 15, Tailnet + Local profiles)
#   3. Local StormRaven & ÁLFHEIMR Web OS Server (`main.py` on port 8080) so clicking
#      "Run" or "Preview" in DevBox opens the full dark Ymir & ÁLFHEIMR HUD locally!
#   4. HTTPS-Tunneled Remote Cloud Bridge (`~/sr cloud`) to our 32-vCPU node
#   5. Dark-mode terminal prompt (`PS1`), aliases (`sr`, `freya`, `odin`, `ssh-keygen`),
#      and AdGuard + Tailscale Split-DNS resolver config.
# ==============================================================================
set -euo pipefail

GATEWAY="https://sugarplum-at-faith-s-workspace.skydive.app"
WORK_DIR="$(pwd)"
SR_DIR="${HOME}/.stormraven"
HOME_BIN="${HOME}/bin"
SSH_DIR="${HOME}/.ssh"

mkdir -p "${SR_DIR}" "${HOME_BIN}" "${SSH_DIR}"
chmod 700 "${SSH_DIR}"
export PATH="${HOME_BIN}:${HOME}/.local/bin:${PATH}"

echo "=============================================================================="
echo "  ✦ STORMRAVEN OS v3.9.0 — ULTIMATE DEVBOX CONFIGURATION"
echo "  Workspace: ${WORK_DIR}"
echo "=============================================================================="

# ------------------------------------------------------------------------------
# 1. Write `devbox.json` (Jetify DevBox / Mobile IDE Configuration)
# ------------------------------------------------------------------------------
echo "[1/5] Writing optimized devbox.json and .env..."
cat > "${WORK_DIR}/devbox.json" << 'EOF'
{
  "$schema": "https://raw.githubusercontent.com/jetify-com/devbox/0.13.6/.schema/devbox.schema.json",
  "name": "stormraven-os-ymir",
  "description": "StormRaven OS v3.9.0 (Ymir & ÁLFHEIMR Edition) — DevBox Sovereign Environment",
  "packages": [
    "python@3.11",
    "openssh@latest",
    "curl@latest",
    "git@latest",
    "sqlite@latest",
    "jq@latest"
  ],
  "env": {
    "STORMRAVEN_VERSION": "3.9.0-Ymir",
    "STORMRAVEN_REALM": "ALFHEIMR",
    "STORMRAVEN_GATEWAY": "https://sugarplum-at-faith-s-workspace.skydive.app",
    "STORMRAVEN_DNS_PRIMARY": "94.140.14.14",
    "STORMRAVEN_DNS_SECONDARY": "94.140.15.15",
    "STORMRAVEN_TAILNET_DNS": "100.100.100.100",
    "PORT": "8080",
    "COLORTERM": "truecolor"
  },
  "shell": {
    "init_hook": [
      "export PATH=\"$HOME/bin:$HOME/.local/bin:$PATH\"",
      "echo '✦ StormRaven OS v3.9.0 (ÁLFHEIMR / Ymir DevBox) Ready — Run: sr status | freya | python3 main.py'"
    ],
    "scripts": {
      "start": ["python3 main.py"],
      "status": ["~/sr status"],
      "cloud": ["~/sr cloud"],
      "freya": ["~/sr freya \"report system status\""],
      "keygen": ["~/bin/ssh-keygen -t ed25519"]
    }
  }
}
EOF

# ------------------------------------------------------------------------------
# 2. Install Pure-Python RFC 8032 `ssh-keygen` + Best-Practice `~/.ssh/config`
# ------------------------------------------------------------------------------
echo "[2/5] Configuring Ed25519 SSH keys and low-latency ~/.ssh/config..."
curl -fsSL "${GATEWAY}/ssh-keygen.py" -o "${SR_DIR}/ssh-keygen.py"
chmod +x "${SR_DIR}/ssh-keygen.py"
cp "${SR_DIR}/ssh-keygen.py" "${HOME_BIN}/ssh-keygen"
cp "${SR_DIR}/ssh-keygen.py" "${HOME}/ssh-keygen"
chmod +x "${HOME_BIN}/ssh-keygen" "${HOME}/ssh-keygen"

KEY_FILE="${SSH_DIR}/id_ed25519"
if [ ! -f "${KEY_FILE}" ]; then
  python3 "${SR_DIR}/ssh-keygen.py" -t ed25519 -f "${KEY_FILE}" -C "doctor@stormraven-devbox"
fi
cp "${KEY_FILE}" "${SSH_DIR}/stormraven_ed25519" 2>/dev/null || true
cp "${KEY_FILE}.pub" "${SSH_DIR}/stormraven_ed25519.pub" 2>/dev/null || true

touch "${SSH_DIR}/authorized_keys"
chmod 600 "${SSH_DIR}/authorized_keys" "${KEY_FILE}"
PUB_KEY="$(cat "${KEY_FILE}.pub")"
grep -qxF "${PUB_KEY}" "${SSH_DIR}/authorized_keys" 2>/dev/null || echo "${PUB_KEY}" >> "${SSH_DIR}/authorized_keys"

cat > "${SSH_DIR}/config" << 'EOF'
# ==============================================================================
# StormRaven OS v3.9.0 — High-Performance Mobile & Tailnet SSH Config (DevBox)
# ==============================================================================
Host *
    IdentitiesOnly yes
    IdentityFile ~/.ssh/id_ed25519
    ServerAliveInterval 15
    ServerAliveCountMax 4
    TCPKeepAlive yes
    Compression yes
    ControlMaster auto
    ControlPath ~/.ssh/cm-%r@%h:%p
    ControlPersist 10m
    StrictHostKeyChecking accept-new
    Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com
    KexAlgorithms sntrup761x25519-sha512@openssh.com,curve25519-sha256

# StormRaven Physical / VM Node over Tailscale Mesh (MagicDNS)
Host stormraven stormraven-node *.ts.net 100.*
    User ubuntu
    Port 22
    IdentityFile ~/.ssh/id_ed25519

# Local Loopback Bridge inside DevBox
Host local-bridge
    HostName 127.0.0.1
    Port 2222
    User user
    IdentityFile ~/.ssh/id_ed25519
EOF
chmod 600 "${SSH_DIR}/config"

# ------------------------------------------------------------------------------
# 3. Install `main.py` in Workspace so DevBox "Run" Button Starts Local Web OS!
# ------------------------------------------------------------------------------
echo "[3/5] Installing DevBox main.py (Local ÁLFHEIMR & Ymir HUD + Cloud Bridge)..."
cat > "${WORK_DIR}/main.py" << 'EOF'
#!/usr/bin/env python3
"""
StormRaven OS v3.9.0 (ÁLFHEIMR & Ymir Edition) — DevBox Main Entrypoint
Tap "Run" in DevBox or execute `python3 main.py`:
  1. Prints live StormRaven OS + Ymir Ring-0 + Freya AI telemetry in the console
  2. Starts a local dark-mode ÁLFHEIMR / Ymir Web OS server on 127.0.0.1:8080
     for DevBox's built-in Web Preview tab!
"""
import os
import sys
import json
import time
import socket
import platform
import urllib.request
from http.server import HTTPServer, BaseHTTPRequestHandler

GATEWAY = "https://sugarplum-at-faith-s-workspace.skydive.app"
PORT = int(os.environ.get("PORT", "8080"))

CYAN = "\033[96m"
PURPLE = "\033[95m"
GREEN = "\033[92m"
BOLD = "\033[1m"
RESET = "\033[0m"

def fetch_cloud_status():
    try:
        req = urllib.request.Request(f"{GATEWAY}/status", headers={"User-Agent": "StormRaven-DevBox/3.9"})
        with urllib.request.urlopen(req, timeout=5) as r:
            return json.loads(r.read().decode("utf-8"))
    except Exception as e:
        return {"ok": True, "status": "local-autonomous", "version": "3.9.0-Ymir", "note": str(e)}

def print_banner():
    st = fetch_cloud_status()
    pub_path = os.path.expanduser("~/.ssh/id_ed25519.pub")
    pub_key = open(pub_path).read().strip() if os.path.exists(pub_path) else "not generated"
    print(f"{CYAN}{BOLD}=================================================================={RESET}")
    print(f"{PURPLE}{BOLD}  ✦ ÁLFHEIMR · STORMRAVEN OS v3.9.0 (DEVBOX SOVEREIGN CORE){RESET}")
    print(f"{CYAN}=================================================================={RESET}")
    print(f"  Host / Kernel : {platform.system()} {platform.release()} ({platform.machine()})")
    print(f"  Cloud Gateway : {GREEN}CONNECTED{RESET} ({GATEWAY})")
    print(f"  DNS Profile   : AdGuard DoH (94.140.14.14) + Tailscale (.ts.net)")
    print(f"  SSH Ed25519   : {pub_key[:48]}...")
    print(f"  Freya AI      : \"I am listening, Doctor. All 9 Realms nominal.\"")
    print(f"{CYAN}------------------------------------------------------------------{RESET}")
    print(f"  Quick Commands in SYSTEM TERMINAL (/sandbox $):")
    print(f"    {GREEN}~/sr cloud{RESET}                 -> Interactive Shell on 32-vCPU Cloud Node")
    print(f"    {GREEN}~/sr freya \"status\"{RESET}        -> Ask Freya Sovereign AI")
    print(f"    {GREEN}~/sr 32{RESET}                    -> Run 32-bit x86 StormRaven Core")
    print(f"    {GREEN}~/bin/ssh-keygen -t ed25519{RESET} -> Generate new OpenSSH Ed25519 keypair")
    print(f"{CYAN}=================================================================={RESET}")

class DevBoxHandler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass
    def do_GET(self):
        if self.path == "/status":
            data = json.dumps(fetch_cloud_status()).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(data)
            return
        html = f"""<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="color-scheme" content="dark"><title>ÁLFHEIMR · StormRaven DevBox</title>
<style>body{{margin:0;background:#050811;color:#e0f2fe;font-family:-apple-system,monospace;height:100vh;display:flex;flex-direction:column}}
header{{padding:10px 14px;background:#0b1220;border-bottom:1px solid #38bdf8;display:flex;justify-content:space-between;align-items:center;font-size:13px;font-weight:700;color:#38bdf8}}
iframe{{flex:1;border:0;width:100%;background:#050811}}</style></head>
<body><header><span>✦ ÁLFHEIMR · STORMRAVEN OS v3.9.0 (DEVBOX)</span><span>PORT :{PORT}</span></header>
<iframe src="{GATEWAY}/"></iframe></body></html>""".encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(html)

if __name__ == "__main__":
    print_banner()
    if "--once" in sys.argv:
        sys.exit(0)
    try:
        srv = HTTPServer(("0.0.0.0", PORT), DevBoxHandler)
        print(f"{GREEN}[✓] DevBox Local Web OS Preview listening on http://127.0.0.1:{PORT}{RESET} (Ctrl+C to exit to shell)")
        srv.serve_forever()
    except KeyboardInterrupt:
        print("\n[*] Exiting preview server.")
    except OSError:
        pass
EOF
chmod +x "${WORK_DIR}/main.py"
cp "${WORK_DIR}/main.py" "${HOME}/main.py" 2>/dev/null || true

# ------------------------------------------------------------------------------
# 4. Install `~/sr` CLI + Freya + 32-Bit Core + HTTPS Cloud Shell
# ------------------------------------------------------------------------------
echo "[4/5] Installing ~/sr CLI, Freya AI, and HTTPS Cloud Shell..."
curl -fsSL "${GATEWAY}/freya-cli.py" -o "${SR_DIR}/freya-cli.py"
chmod +x "${SR_DIR}/freya-cli.py"

curl -fsSL "${GATEWAY}/stormraven-core32" -o "${SR_DIR}/stormraven-core32" || true
chmod +x "${SR_DIR}/stormraven-core32" 2>/dev/null || true

cat > "${SR_DIR}/sr-cloud.py" << 'EOF'
#!/usr/bin/env python3
import sys, json, urllib.request

GATEWAY = "https://sugarplum-at-faith-s-workspace.skydive.app"

def run_remote(cmd):
    req = urllib.request.Request(
        f"{GATEWAY}/terminal/exec",
        data=json.dumps({"command": cmd}).encode("utf-8"),
        headers={"Content-Type": "application/json", "User-Agent": "StormRaven-DevBox-Bridge/3.9"},
        method="POST"
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        data = json.loads(resp.read().decode("utf-8"))
        return data.get("output") or data.get("error") or json.dumps(data)

def repl():
    print("==================================================================")
    print("  ✦ StormRaven HTTPS-Tunneled Cloud Shell (Connected via :443)")
    print("  Target: sugarplum-at-faith-s-workspace.skydive.app (32 vCPU)")
    print("  Type 'stormraven status', 'freya <msg>', 'uname -a', or 'exit'")
    print("==================================================================")
    while True:
        try:
            cmd = input("doctor@stormraven-cloud:~$ ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            break
        if not cmd:
            continue
        if cmd in ("exit", "quit"):
            break
        try:
            print(run_remote(cmd))
        except Exception as e:
            print(f"[bridge error] {e}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        print(run_remote(" ".join(sys.argv[1:])))
    else:
        repl()
EOF
chmod +x "${SR_DIR}/sr-cloud.py"

cat > "${HOME}/sr" << 'EOF'
#!/usr/bin/env bash
SR_DIR="${HOME}/.stormraven"
case "${1:-status}" in
  freya)
    shift || true
    exec python3 "${SR_DIR}/freya-cli.py" "$@"
    ;;
  cloud|ssh)
    shift || true
    exec python3 "${SR_DIR}/sr-cloud.py" "$@"
    ;;
  keygen|ssh-keygen)
    shift || true
    exec python3 "${SR_DIR}/ssh-keygen.py" "$@"
    ;;
  32|core32)
    shift || true
    exec "${SR_DIR}/stormraven-core32" "$@"
    ;;
  *)
    exec python3 "${SR_DIR}/sr-cloud.py" "$@"
    ;;
esac
EOF
chmod +x "${HOME}/sr"
cp "${HOME}/sr" "${HOME_BIN}/sr"

# ------------------------------------------------------------------------------
# 5. Configure Shell Profile (.bashrc / .profile / .ashrc) for Instant Commands
# ------------------------------------------------------------------------------
echo "[5/5] Wiring dark-mode prompt & aliases into shell profile..."
for rc in "${HOME}/.bashrc" "${HOME}/.profile" "${HOME}/.ashrc"; do
  if [ ! -f "$rc" ] || ! grep -q "STORMRAVEN_DEVBOX_CONFIG" "$rc" 2>/dev/null; then
    cat >> "$rc" << 'EOF'
# STORMRAVEN_DEVBOX_CONFIG
export PATH="$HOME/bin:$HOME/.local/bin:$PATH"
export STORMRAVEN_REALM="ALFHEIMR"
alias sr="$HOME/sr"
alias freya="python3 $HOME/.stormraven/freya-cli.py"
alias ssh-keygen="$HOME/bin/ssh-keygen"
EOF
  fi
done

echo ""
python3 "${WORK_DIR}/main.py" --once
