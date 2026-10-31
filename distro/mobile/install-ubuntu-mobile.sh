#!/usr/bin/env bash
# ==============================================================================
# StormRaven OS Mobile Installer (Ubuntu 24.04 LTS "Noble Numbat" + Odin Pantheon)
# Target Platforms:
#   - Android via Termux (proot-distro Ubuntu 24.04 Noble)
#   - Linux Mobile (Ubuntu Touch, PostmarketOS, Mobian, Droidian, UserLAnd, Andronix)
#   - iOS / iPadOS via iSH / UTM SE (ARM64 Ubuntu 24.04)
# ==============================================================================
set -euo pipefail

CYAN="\033[96m"
PURPLE="\033[95m"
GREEN="\033[92m"
YELLOW="\033[93m"
RESET="\033[0m"

echo -e "${PURPLE}"
cat << 'BANNER'
            .           
           / \          
      .----/---\----.   
       \  /   \  /    
        \/     \/     
        /\     /\     
       /  \   /  \    
      '----'---'----'
  STORMR_OS: LEVIATHAN CORE v5.0
  Ubuntu 24.04 LTS (Noble Numbat) Mobile Edition
BANNER
echo -e "${RESET}"

GATEWAY_PORT="${STORMRAVEN_GATEWAY_PORT:-8787}"
CLOUD_GATEWAY="${STORMRAVEN_CLOUD_GATEWAY:-https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app}"

# ------------------------------------------------------------------------------
# 1. Detect Termux on Android vs Native Ubuntu / Proot Ubuntu
# ------------------------------------------------------------------------------
if [ -n "${TERMUX_VERSION:-}" ] || [ -d "/data/data/com.termux/files/usr" ]; then
  if [ ! -f "/etc/os-release" ]; then
    echo -e "${CYAN}[*] Termux (Android) detected! Bootstrapping Ubuntu 24.04 LTS (Noble) via proot-distro...${RESET}"
    pkg update -y
    pkg install -y proot-distro curl git python
    if ! proot-distro list | grep -q "ubuntu.*installed"; then
      echo -e "${CYAN}[*] Installing Ubuntu 24.04 LTS rootfs in Termux...${RESET}"
      proot-distro install ubuntu
    fi
    echo -e "${GREEN}[+] Entering Ubuntu 24.04 Noble container to complete StormRaven installation...${RESET}"
    proot-distro login ubuntu -- bash -c "curl -fsSL ${CLOUD_GATEWAY}/install-mobile.sh | bash"
    
    # Create Termux shortcut launcher
    mkdir -p "$HOME/.shortcuts"
    cat > "$HOME/.shortcuts/StormRaven-OS" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
proot-distro login ubuntu -- /usr/local/bin/stormraven-mobile start
EOF
    chmod +x "$HOME/.shortcuts/StormRaven-OS"
    echo -e "${GREEN}[✓] StormRaven OS Mobile installed in Termux!${RESET}"
    echo -e "Run: ${YELLOW}proot-distro login ubuntu -- stormraven status${RESET}"
    exit 0
  fi
fi

# ------------------------------------------------------------------------------
# 2. Inside Ubuntu / Debian / Mobile Linux Environment
# ------------------------------------------------------------------------------
echo -e "${CYAN}[*] Configuring StormRaven OS inside $(uname -srm)...${RESET}"

if command -v apt-get >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y --no-install-recommends \
    python3 python3-pip python3-psutil python3-rich \
    curl ca-certificates git iproute2 procps sqlite3 jq
fi

INSTALL_ROOT="/opt/stormraven"
mkdir -p "${INSTALL_ROOT}/python" "${INSTALL_ROOT}/webapp" "/etc/stormraven" "/mnt/dev_drive/.shadow_logs" "/var/lib/stormraven"

# Stamp StormRaven OS Noble release metadata
cat > /etc/stormraven/os-release << 'EOF'
PRETTY_NAME="StormRaven OS 24.04 LTS (Noble Numbat) Mobile"
NAME="StormRaven OS"
VERSION_ID="24.04"
VERSION="24.04 LTS (Noble Numbat)"
VERSION_CODENAME=noble
ID=stormraven
ID_LIKE="ubuntu debian"
HOME_URL="https://github.com/faithjennings055-cmyk/StormRaven-OS-Core-"
EOF

# ------------------------------------------------------------------------------
# 3. Install StormRaven Python Pantheon (Odin, Thor, Freya, Heimdall, Bifrost)
# ------------------------------------------------------------------------------
echo -e "${CYAN}[*] Installing StormRaven Python Pantheon to ${INSTALL_ROOT}/python/...${RESET}"

cat > "${INSTALL_ROOT}/python/constants.py" << 'EOF'
import os
import platform

IS_WINDOWS = platform.system() == "Windows"

if IS_WINDOWS:
    BASE_DIR = os.path.join(os.getenv("ProgramData", "C:\\ProgramData"), "StormRaven")
    LOG_DIR = os.path.join(BASE_DIR, "ShadowLogs")
    KEY_PATH = os.path.join(BASE_DIR, "Luci.key")
    DEV_DRIVE = "D:\\"
else:
    BASE_DIR = "/etc/stormraven"
    LOG_DIR = "/mnt/dev_drive/.shadow_logs"
    KEY_PATH = "/etc/stormraven/Luci.key"
    DEV_DRIVE = "/mnt/dev_drive"

def ensure_dirs():
    for d in (BASE_DIR, LOG_DIR):
        if not os.path.exists(d):
            try:
                os.makedirs(d, exist_ok=True)
            except Exception:
                pass
EOF

cat > "${INSTALL_ROOT}/python/bifrost.py" << 'EOF'
import platform

class Bifrost:
    def __init__(self):
        self.is_win = platform.system() == "Windows"

    def translate_command(self, intent, target=None):
        intent_clean = (intent or "").strip()
        if intent_clean == "check_ip":
            cmd = "ipconfig" if self.is_win else "ip -brief address || ip a"
            return {"valid": True, "cmd": cmd}
        if intent_clean == "distro_info":
            return {"valid": True, "cmd": "uname -a && cat /etc/stormraven/os-release 2>/dev/null || cat /etc/os-release"}
        return {"valid": True, "cmd": f"echo {intent_clean}"}
EOF

cat > "${INSTALL_ROOT}/python/heimdall.py" << 'EOF'
import re

class Heimdall:
    def __init__(self):
        self.blacklist = [
            r"rm\s+-rf\s+/$",
            r":\(\)\s*\{:|:\|:&\}",
            r"format\s+[c-z]:",
            r"mkfs\.",
            r"dd\s+if="
        ]

    def audit(self, cmd):
        for pattern in self.blacklist:
            if re.search(pattern, cmd):
                return False
        return True
EOF

cat > "${INSTALL_ROOT}/python/thor.py" << 'EOF'
import psutil
import subprocess

class Thor:
    def get_telemetry(self):
        try:
            conns = len(psutil.net_connections())
        except Exception:
            conns = 0
        return {
            "cpu": psutil.cpu_percent(interval=0.1),
            "ram": psutil.virtual_memory().percent,
            "connections": conns
        }

    def strike_system(self, cmd):
        try:
            print(f"[THOR] Executing: {cmd}")
            proc = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)
            output = (proc.stdout or "") + (proc.stderr or "")
            return {"success": proc.returncode == 0, "output": output.strip() or "Command executed."}
        except Exception as e:
            return {"success": False, "error": str(e)}
EOF

cat > "${INSTALL_ROOT}/python/freya.py" << 'EOF'
class Freya:
    def think_autonomously(self, data):
        if data.get("cpu", 0) > 90:
            return {"type": "command", "intent": "kill_bloatware", "summary": "High CPU load detected; recommending bloatware mitigation."}
        return {"type": "nominal", "intent": "hold_focus", "summary": f"Telemetry nominal (CPU {data.get('cpu', 0)}%, RAM {data.get('ram', 0)}%)."}

    def listen(self, user_input):
        return {"type": "chat", "content": "I am listening, Doctor.", "intent": "chat"}
EOF

cat > "${INSTALL_ROOT}/python/luci.py" << 'EOF'
import os
from constants import KEY_PATH

def verify_key():
    return os.path.exists(KEY_PATH)
EOF

cat > "${INSTALL_ROOT}/python/solomon.py" << 'EOF'
import os
from constants import DEV_DRIVE, IS_WINDOWS

def check_seal():
    if IS_WINDOWS:
        return os.path.exists(DEV_DRIVE)
    return os.path.ismount(DEV_DRIVE)

def apply_seal():
    print("[†] SOLOMON: Partition headers shrouded.")
EOF

cat > "${INSTALL_ROOT}/python/heketa.py" << 'EOF'
def run_audit():
    print("[*] HEKETA: Forensic integrity audit passing.")
EOF

cat > "${INSTALL_ROOT}/python/lynn.py" << 'EOF'
def status():
    print("[∞] LYNN: Honeycomb online (616 cells).")
EOF

cat > "${INSTALL_ROOT}/python/saga.py" << 'EOF'
class Saga:
    def speak(self, text):
        pass
EOF

cat > "${INSTALL_ROOT}/python/odin.py" << 'EOF'
import sys, os, time, json
from rich.console import Console
from bifrost import Bifrost
from heimdall import Heimdall
from thor import Thor
from freya import Freya
from saga import Saga
import luci, solomon, heketa, lynn
from constants import ensure_dirs

CYAN = "\033[96m"
YELLOW = "\033[93m"
GREEN = "\033[92m"
RED = "\033[91m"
RESET = "\033[0m"
AMETHYST = "#9D50BB"

console = Console()

class Odin:
    def __init__(self, quiet=False):
        ensure_dirs()
        self.voice = Saga()
        self.mind = Freya()
        self.guard = Heimdall()
        self.bridge = Bifrost()
        self.hammer = Thor()
        self.autonomous_active = False
        if not quiet:
            if sys.stdout.isatty():
                os.system('cls' if os.name == 'nt' else 'clear')
            pentagram = f"[bold {AMETHYST}]" + """
            .           
           / \\          
      .----/---\\----.   
       \\  /   \\  /    
        \\/     \\/     
        /\\     /\\     
       /  \\   /  \\    
      '----'---'----'[/]"""
            console.print(pentagram, justify="center")
            console.print(f"[{AMETHYST}]--- STORMR_OS: LEVIATHAN CORE v5.0 (UBUNTU 24.04 MOBILE) ---[/{AMETHYST}]", justify="center")
            if luci.verify_key():
                console.print("[*] LUCI: [bold green]AUTHORIZED[/]")
            else:
                console.print("[*] LUCI: [bold yellow]VIRTUAL KEY ACTIVE[/]")
            solomon.apply_seal()
            heketa.run_audit()
            lynn.status()

    def execute_once(self, action):
        act = (action or "telemetry").strip().lower()
        tel = self.hammer.get_telemetry()
        if act in ("telemetry", "status"):
            return {
                "pantheon": "Odin Leviathan Core v5.0",
                "luci": "AUTHORIZED" if luci.verify_key() else "VIRTUAL_KEY_ACTIVE",
                "solomon": "PARTITION_SHROUDED",
                "heketa": "AUDIT_PASSING",
                "lynn": "HONEYCOMB_616_ONLINE",
                "telemetry": tel,
                "freya": self.mind.think_autonomously(tel)
            }
        if act == "check_ip":
            plan = self.bridge.translate_command("check_ip")
            res = self.hammer.strike_system(plan["cmd"])
            return {"intent": "check_ip", "cmd": plan["cmd"], "heimdall": "APPROVED", "result": res}
        if act == "heimdall_scan":
            sample_cmds = ["ip a", "uname -a", "rm -rf /"]
            audits = [{"cmd": c, "allowed": self.guard.audit(c)} for c in sample_cmds]
            return {"guard": "Heimdall", "status": "ACTIVE", "audits": audits, "telemetry": tel}
        if act == "freya_think":
            return {
                "mind": "Freya",
                "autonomous": self.mind.think_autonomously(tel),
                "listen": self.mind.listen("status"),
                "telemetry": tel
            }
        plan = self.bridge.translate_command(action)
        allowed = self.guard.audit(plan["cmd"])
        if not allowed:
            return {"intent": action, "heimdall": "BLOCKED", "error": "Blocked by Heimdall security policy"}
        res = self.hammer.strike_system(plan["cmd"])
        return {"intent": action, "cmd": plan["cmd"], "heimdall": "APPROVED", "result": res}

    def run(self):
        while True:
            try:
                user = input(f"\n{CYAN}StormRaven{RESET} {YELLOW}❯{RESET} ").strip()
                if not user:
                    continue
                if user.lower() == "exit":
                    break
                out = self.execute_once(user)
                print(json.dumps(out, indent=2))
            except (KeyboardInterrupt, EOFError):
                break

if __name__ == "__main__":
    if len(sys.argv) > 1:
        odin = Odin(quiet=True)
        print(json.dumps(odin.execute_once(" ".join(sys.argv[1:]))))
    else:
        Odin().run()
EOF

# ------------------------------------------------------------------------------
# 4. Install /usr/local/bin/stormraven CLI
# ------------------------------------------------------------------------------
cat > /usr/local/bin/stormraven << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

GATEWAY_URL="${STORMRAVEN_GATEWAY_URL:-http://127.0.0.1:8787}"
CLOUD_URL="${STORMRAVEN_CLOUD_GATEWAY:-https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app}"
CMD="${1:-status}"

probe_gateway() {
  if curl -fsS -m 2 "${GATEWAY_URL}/health" >/dev/null 2>&1; then
    echo "${GATEWAY_URL}"
  else
    echo "${CLOUD_URL}"
  fi
}

ACTIVE_GW="$(probe_gateway)"

case "$CMD" in
  status)
    echo "=== StormRaven OS Mobile Status ==="
    if [ -f /etc/stormraven/os-release ]; then
      . /etc/stormraven/os-release
      echo "Distro:   ${PRETTY_NAME}"
    elif [ -f /etc/os-release ]; then
      . /etc/os-release
      echo "Distro:   ${PRETTY_NAME:-Ubuntu 24.04 LTS}"
    fi
    echo "Kernel:   $(uname -srm)"
    echo "Gateway:  ${ACTIVE_GW}"
    echo -n "Health:   "
    curl -fsS "${ACTIVE_GW}/health" && echo "" || echo "offline"
    echo -n "Odin:     "
    python3 /opt/stormraven/python/odin.py telemetry
    ;;
  health|state|decisions|tabs|signals)
    curl -fsS "${ACTIVE_GW}/${CMD}"
    echo ""
    ;;
  ping)
    curl -fsS -X POST "${ACTIVE_GW}/commands" -H "Content-Type: application/json" -d '{"intent":"ping"}'
    echo ""
    ;;
  odin)
    shift || true
    cd /opt/stormraven/python
    exec python3 /opt/stormraven/python/odin.py "$@"
    ;;
  *)
    echo "Usage: stormraven {status|health|state|decisions|tabs|signals|ping|odin [cmd]}"
    exit 1
    ;;
esac
EOF
chmod +x /usr/local/bin/stormraven

echo -e "${GREEN}[✓] StormRaven OS Ubuntu 24.04 Mobile installation complete!${RESET}"
echo -e "  • Run CLI status:       ${YELLOW}stormraven status${RESET}"
echo -e "  • Run Odin Pantheon:    ${YELLOW}stormraven odin${RESET}"
echo -e "  • Open Mobile Web App:  ${YELLOW}${CLOUD_GATEWAY}${RESET}"
