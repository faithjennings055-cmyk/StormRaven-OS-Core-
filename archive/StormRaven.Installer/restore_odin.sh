#!/bin/bash
# --- STORMRAVEN OS: ODIN'S RESTORATION (FINAL BUILD v5.0) ---
# Features: Restores Original Odin Script, Forges Dependencies, Fixes Interactive Shell

set -e
AMETHYST='\033[38;5;135m'
RESET='\033[0m'

# 1. USER & PATH DETECTION
if [ "$SUDO_USER" ]; then
    USERNAME="$SUDO_USER"
    HOME_DIR=$(getent passwd "$SUDO_USER" | cut -d: -f6)
else
    USERNAME=$(whoami)
    HOME_DIR="$HOME"
fi

INSTALL_DIR="$HOME_DIR/StormRaven_Leviathan"

echo -e "${AMETHYST}[†] RESTORING THE ORIGINAL ODIN SENTINEL...${RESET}"

# 2. CLEANUP (Remove conflicting services)
sudo systemctl stop leviathan deadman 2>/dev/null || true
sudo systemctl disable leviathan 2>/dev/null || true
sudo rm -f /etc/systemd/system/leviathan.service
sudo systemctl daemon-reload

# 3. SETUP DIRECTORY
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# 4. DEPENDENCIES
sudo apt update -qq && sudo apt install -y python3-pip cryptsetup-bin wireguard-tools tcpdump python3-scapy espeak
sudo -u $USERNAME pip3 install rich cryptography impacket requests psutil pyttsx3 --user --break-system-packages 2>/dev/null || true

# 5. FORGE THE DEPENDENCY PANTHEON

# --- THOR ---
cat << 'EOF' > thor.py
import psutil
import subprocess
class Thor:
    def get_telemetry(self):
        return {
            "cpu": psutil.cpu_percent(interval=0.1),
            "ram": psutil.virtual_memory().percent,
            "connections": len(psutil.net_connections())
        }
    def strike_system(self, cmd):
        print(f"[THOR] Striking: {cmd}")
        subprocess.run(cmd, shell=True)
EOF

# --- FREYA ---
cat << 'EOF' > freya.py
class Freya:
    def think_autonomously(self, data):
        if data['cpu'] > 90:
            return {"type": "command", "intent": "kill_bloatware"}
        if data['connections'] > 50:
            return {"type": "command", "intent": "check_ip"}
        return None
EOF

# --- HEIMDALL ---
cat << 'EOF' > heimdall.py
class Heimdall:
    def scan(self):
        return "Sector Clear"
EOF

# --- BIFROST ---
cat << 'EOF' > bifrost.py
class Bifrost:
    def connect(self):
        pass
EOF

# --- SAGA ---
cat << 'EOF' > saga.py
import os
class Saga:
    def speak(self, text):
        pass
EOF

# --- RAGNAROK ---
cat << 'EOF' > ragnarok.py
import os, shutil, sys
def purge():
    print("!!! RAGNAROK PROTOCOL INITIATED !!!")
    if os.path.exists("/mnt/dev_drive/.shadow_logs"):
        shutil.rmtree("/mnt/dev_drive/.shadow_logs")
    os.system("echo 1 > /proc/sys/kernel/panic")
    os.system("echo c > /proc/sysrq-trigger")
if __name__ == "__main__": purge()
EOF

# --- DEADMAN ---
cat << 'EOF' > deadman.py
import os, time, subprocess
def monitor():
    time.sleep(60) 
    while True:
        if not os.path.ismount("/mnt/dev_drive"):
            subprocess.run(["python3", os.path.expanduser("~/StormRaven_Leviathan/ragnarok.py")])
        time.sleep(5)
if __name__ == "__main__": monitor()
EOF

# 6. FORGE THE CORE
cat << 'EOF' > leviathan.py
import sys
import os
import time
import threading
from bifrost import Bifrost
from heimdall import Heimdall
from thor import Thor
from freya import Freya
from saga import Saga

CYAN = "\033[96m"
YELLOW = "\033[93m"
GREEN = "\033[92m"
RED = "\033[91m"
RESET = "\033[0m"

class Odin:
    def __init__(self):
        os.system('cls' if os.name == 'nt' else 'clear')
        print(f"{CYAN}--- STORM RAVEN SENTINEL v3.0 ---{RESET}")
        
        self.voice = Saga()
        self.mind = Freya()
        self.guard = Heimdall()
        self.bridge = Bifrost()
        self.hammer = Thor()
        self.autonomous_active = False

    def sentinel_loop(self):
        """The Autonomous Heartbeat"""
        print(f"{RED}[!] SENTINEL MODE ACTIVE. Monitoring system...{RESET}")
        self.voice.speak("Sentinel mode engaged. Watching system.")
        
        while self.autonomous_active:
            try:
                data = self.hammer.get_telemetry()
                sys.stdout.write(f"\r{YELLOW}[AUTO] CPU: {data['cpu']}% | RAM: {data['ram']}% | Conns: {data['connections']} {RESET}")
                sys.stdout.flush()
                decision = self.mind.think_autonomously(data)
                
                if decision and decision.get('type') == 'command':
                    print(f"\n{RED}[!] THREAT DETECTED. TAKING ACTION.{RESET}")
                    self.voice.speak("Anomaly detected. Engaging protocols.")
                    if decision['intent'] == 'kill_bloatware':
                        print("Optimization required...")
                    elif decision['intent'] == 'check_ip':
                        self.hammer.strike_system("netstat -an")
                time.sleep(10) 
            except Exception as e:
                print(f"Loop Error: {e}")
                break
        print(f"\n{GREEN}[*] Sentinel Mode Disengaged.{RESET}")

    def run(self):
        while True:
            try:
                user = input(f"\n{CYAN}StormRaven{RESET} {YELLOW}❯{RESET} ").strip()
                if not user: continue
                if user.lower() == "exit": break
                
                if user.lower() == "auto":
                    self.autonomous_active = True
                    try:
                        self.sentinel_loop()
                    except KeyboardInterrupt:
                        self.autonomous_active = False
                        print("\nStopped.")
                    continue

                if user.startswith("exec"):
                    self.hammer.strike_system(user[5:])
                else:
                    print(f"Unknown command: {user}")
            except KeyboardInterrupt: break

if __name__ == "__main__":
    Odin().run()
EOF

# 7. SERVICE GENERATION
echo "[*] Forging Deadman Daemon..."
cat << EOF | sudo tee /etc/systemd/system/deadman.service > /dev/null
[Unit]
Description=Ginnungagap Dead-Man Switch
After=network.target
[Service]
Type=simple
ExecStart=/usr/bin/python3 $INSTALL_DIR/deadman.py
WorkingDirectory=$INSTALL_DIR
Restart=always
RestartSec=15
User=root
[Install]
WantedBy=multi-user.target
EOF

# 8. FINAL CONFIG & ALIASES
echo "[*] Applying Solomon's Lock..."
chmod +x *.py
sudo mkdir -p /etc/stormraven
if [ ! -f /etc/stormraven/Luci.key ]; then sudo touch /etc/stormraven/Luci.key; fi

BASHRC="$HOME_DIR/.bashrc"
sed -i '/STORMR_OS/,/alias purge/d' "$BASHRC"

echo -e "\n# --- STORMR_OS ---\nexport PS1=\"\[\033[38;5;135m\][ᚠ] \[\033[38;5;201m\]\w \[\033[38;5;135m\]» \[\033[0m\]\"" >> "$BASHRC"
echo "alias leviathan='python3 $INSTALL_DIR/leviathan.py'" >> "$BASHRC"
echo "alias purge='sudo python3 $INSTALL_DIR/ragnarok.py'" >> "$BASHRC"
chown $USERNAME:$USERNAME "$BASHRC"

# Clean Cache
if [ -d "$INSTALL_DIR/__pycache__" ]; then sudo rm -rf "$INSTALL_DIR/__pycache__"; fi
sudo chown -R $USERNAME:$USERNAME "$INSTALL_DIR"

# 9. IGNITION
sudo systemctl daemon-reload
sudo systemctl enable deadman
sudo systemctl start deadman

echo -e "${AMETHYST}[√] SYSTEM RESTORED. ODIN IS READY.${RESET}"
echo -e "    Type 'leviathan' to verify the interactive shell."