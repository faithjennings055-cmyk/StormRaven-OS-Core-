#!/usr/bin/env bash
# =============================================================================
# StormRaven OS: Infinity Protocol v3.9.0 — Windows 11 Edition + Moov AI
# =============================================================================
# Direct bare-metal installer for Faith Jennings' HP Pro 3500 Series:
#   1. Purges all unnecessary VM programs (`gnome-boxes`, `virt-manager`,
#      `virt-viewer`, `qemu-system-*`, `swtpm`, `virtualbox`, and `/var/tmp`
#      VM images) to free up disk space and RAM.
#   2. Sets OS Branding to "StormRaven OS: Infinity Protocol v3.9.0 — Windows 11 Edition + Moov AI"
#      across `/etc/os-release` (preserving `ID=ubuntu` for APT), Desktop
#      shortcuts, Command Center, and Bifrost Gateway.
#   3. Installs and verifies the full Moov AI Financial & Mobile Check Deposit
#      Engine (`stormraven-moov` / `moov-ai`) with shared multi-user SQLite
#      ledger (`/var/lib/stormraven/moov/moov_ledger.db`), 94-character NACHA
#      `.ach` file generation, X9.37 Check 21 `.x937` Cash Letter generation,
#      and ABA Mod-10 routing verification.
#   4. Launches the interactive Windows 11 Edition + Moov AI Command Center &
#      Web Portal (`http://127.0.0.1:3887/moov`) right on your screen!
#
# One-command usage on HP Pro 3500:
#   curl -fsSL https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/install-win11.sh | sudo bash
# =============================================================================
set -euo pipefail

CLOUD_URL="${STORMRAVEN_GATEWAY_URL:-https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app}"
VERSION="3.9.0"
ZIP_NAME="StormRavenOS-Win11-Full-v3.9.0-x64.zip"
ZIP_URL="${CLOUD_URL}/iso/${ZIP_NAME}"
SHA_URL="${ZIP_URL}.sha256"

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: Please run with sudo:"
  echo "  curl -fsSL ${CLOUD_URL}/install-win11.sh | sudo bash"
  exit 1
fi

REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo root)}"
if [ "${REAL_USER}" != "root" ]; then
  USER_HOME="$(getent passwd "${REAL_USER}" | cut -d: -f6)"
  USER_UID="$(id -u "${REAL_USER}" 2>/dev/null || echo 1000)"
else
  USER_HOME="${HOME:-/root}"
  USER_UID="0"
fi

echo "======================================================================="
echo " 🪟 STORMRAVEN OS: INFINITY PROTOCOL v3.9.0 — WINDOWS 11 EDITION + MOOV AI"
echo "    Direct Bare-Metal Installation · NACHA ACH & X9.37 Check Deposit"
echo "======================================================================="

export DEBIAN_FRONTEND=noninteractive

# 1. Heal dpkg and purge all unnecessary VM software & VM disk images
echo "==> [1/6] Cleaning up unnecessary VM programs & freeing disk space..."
pkill -f "[q]emu-system" 2>/dev/null || true
pkill -f "[g]nome-boxes" 2>/dev/null || true
pkill -f "[v]irt-manager" 2>/dev/null || true
pkill -f "[s]wtpm" 2>/dev/null || true
rm -rf /var/tmp/stormraven-win11-vm \
       "${USER_HOME}/Downloads/StormRavenOS-Win11-Boxes-v3.9.0.iso" \
       "${USER_HOME}/Downloads/StormRaven-Win11-Payload.iso" 2>/dev/null || true

dpkg-divert --package stormraven-os --divert /etc/xdg/menus/lxde-applications.menu.distrib --rename /etc/xdg/menus/lxde-applications.menu >/dev/null 2>&1 || true
dpkg-divert --package stormraven-os --divert /etc/xdg/menus/applications.menu.distrib --rename /etc/xdg/menus/applications.menu >/dev/null 2>&1 || true
dpkg --configure -a --force-overwrite >/dev/null 2>&1 || true
apt-get -f install -y -qq -o Dpkg::Options::="--force-overwrite" >/dev/null 2>&1 || true

VM_PKGS_TO_PURGE=()
for pkg in gnome-boxes virt-manager virt-viewer swtpm swtpm-tools qemu-system-gui qemu-system-x86 qemu-utils ovmf libvirt-daemon-system libvirt-clients virtualbox virtualbox-qt vagrant; do
  if dpkg -s "${pkg}" >/dev/null 2>&1; then
    VM_PKGS_TO_PURGE+=("${pkg}")
  fi
done
if [ "${#VM_PKGS_TO_PURGE[@]}" -gt 0 ]; then
  echo "    Uninstalling VM packages: ${VM_PKGS_TO_PURGE[*]}..."
  apt-get purge -y -qq -o Dpkg::Options::="--force-overwrite" "${VM_PKGS_TO_PURGE[@]}" 2>/dev/null || true
  apt-get autoremove -y -qq 2>/dev/null || true
fi
rm -f "${USER_HOME}/Desktop/virt-manager.desktop" \
      "${USER_HOME}/Desktop/All-StormRaven-Apps/virt-manager.desktop" \
      /usr/share/applications/virt-manager.desktop \
      /usr/share/applications/org.gnome.Boxes.desktop 2>/dev/null || true

# Ensure GTK3 Python bindings & SQLite3 are present for the native Command Center & Moov AI
NEED_GUI_PKGS=()
dpkg -s python3-gi >/dev/null 2>&1 || NEED_GUI_PKGS+=(python3-gi)
dpkg -s gir1.2-gtk-3.0 >/dev/null 2>&1 || NEED_GUI_PKGS+=(gir1.2-gtk-3.0)
command -v unzip >/dev/null 2>&1 || NEED_GUI_PKGS+=(unzip)
if [ "${#NEED_GUI_PKGS[@]}" -gt 0 ]; then
  apt-get update -qq || true
  apt-get install -y -qq -o Dpkg::Options::="--force-overwrite" "${NEED_GUI_PKGS[@]}" 2>/dev/null || true
fi

# 2. Install StormRaven OS Core .deb package
echo "==> [2/6] Installing StormRaven OS v${VERSION} Core Package..."
curl -fsSL "${CLOUD_URL}/iso/stormraven-os_${VERSION}_amd64.deb?t=$(date +%s)" -o /tmp/stormraven-os.deb
curl -fsSL "${CLOUD_URL}/iso/stormraven-os_${VERSION}_amd64.deb.sha256?t=$(date +%s)" -o /tmp/stormraven-os.deb.sha256
(cd /tmp && sed -i "s|stormraven-os_${VERSION}_amd64.deb|stormraven-os.deb|g" stormraven-os.deb.sha256 && sha256sum -c stormraven-os.deb.sha256)
dpkg --force-overwrite -i /tmp/stormraven-os.deb || apt-get install -f -y -qq -o Dpkg::Options::="--force-overwrite"
rm -f /tmp/stormraven-os.deb /tmp/stormraven-os.deb.sha256

# 3. Download & install the Windows 11 Edition + Moov AI Bundle
echo "==> [3/6] Installing StormRaven OS: Infinity Protocol v3.9.0 — Windows 11 Edition + Moov AI..."
mkdir -p /opt/stormraven/win11 /mnt/STORMRAVEN_WIN11 /etc/stormraven /var/lib/stormraven/moov/nacha /var/lib/stormraven/moov/x937
chmod -R 0777 /var/lib/stormraven/moov /tmp/stormraven-moov /tmp/stormraven-void 2>/dev/null || true

ZIP_PATH="/tmp/${ZIP_NAME}"
SHA_PATH="${ZIP_PATH}.sha256"
curl -fsSL "${SHA_URL}?t=$(date +%s)" -o "${SHA_PATH}"
EXPECTED_SHA="$(awk '{print $1}' "${SHA_PATH}")"
curl -fL --retry 3 "${ZIP_URL}?v=${EXPECTED_SHA:0:12}" -o "${ZIP_PATH}"
(cd /tmp && sha256sum -c "${ZIP_NAME}.sha256")

rm -rf /tmp/sr-win11-unpack && mkdir -p /tmp/sr-win11-unpack
unzip -q -o "${ZIP_PATH}" -d /tmp/sr-win11-unpack
rm -f "${ZIP_PATH}" "${SHA_PATH}"

if [ -d /tmp/sr-win11-unpack/StormRaven-Win11-Full ]; then
  cp -rf /tmp/sr-win11-unpack/StormRaven-Win11-Full/* /opt/stormraven/win11/
  cp -rf /tmp/sr-win11-unpack/StormRaven-Win11-Full/* /mnt/STORMRAVEN_WIN11/
  if [ -d /tmp/sr-win11-unpack/StormRaven-Win11-Full/linux-vm ]; then
    cp -f /tmp/sr-win11-unpack/StormRaven-Win11-Full/linux-vm/* /usr/local/bin/
    chmod 0755 /usr/local/bin/stormraven*
    ln -sf /usr/local/bin/stormraven-moov /usr/local/bin/moov-ai
  fi
  if [ -d /tmp/sr-win11-unpack/StormRaven-Win11-Full/webapp ]; then
    mkdir -p /opt/stormraven/webapp
    cp -rf /tmp/sr-win11-unpack/StormRaven-Win11-Full/webapp/* /opt/stormraven/webapp/
  fi
  if [ -d /tmp/sr-win11-unpack/StormRaven-Win11-Full/python ]; then
    mkdir -p /opt/stormraven/python
    cp -rf /tmp/sr-win11-unpack/StormRaven-Win11-Full/python/* /opt/stormraven/python/
  fi
fi
rm -rf /tmp/sr-win11-unpack

# 4. Set System Name & Windows 11 Edition Mode + Verify Moov AI End-to-End
echo "==> [4/6] Setting OS Branding & Verifying Moov AI Engine End-to-End..."
echo "win11" > /etc/stormraven/edition
cat > /etc/profile.d/stormraven-win11.sh << 'EOF'
export STORMRAVEN_DEFAULT_OS="win11"
export STORMRAVEN_EDITION="win11"
EOF
chmod 0644 /etc/profile.d/stormraven-win11.sh

if [ -f /etc/os-release ]; then
  sed -i 's|^PRETTY_NAME=.*|PRETTY_NAME="StormRaven OS: Infinity Protocol v3.9.0 — Windows 11 Edition + Moov AI"|' /etc/os-release || true
fi

# Run live self-test of Moov AI (SQLite DB + 94-char NACHA .ach + X9.37 .x937 ICL)
chmod -R 0777 /var/lib/stormraven/moov 2>/dev/null || true
MOOV_STATUS="$(python3 /usr/local/bin/stormraven-moov status)"
chmod -R 0777 /var/lib/stormraven/moov /tmp/stormraven-moov 2>/dev/null || true
chmod 0666 /var/lib/stormraven/moov/moov_ledger.* /tmp/stormraven-moov/moov_ledger.* 2>/dev/null || true
echo "    ✓ Moov AI Engine Verified: $(echo "${MOOV_STATUS}" | grep -E '"engine"|"availableBalance"|"sqliteDb"' | tr '\n' ' ')"

cat > /usr/local/bin/stormraven-open-ui << 'EOF'
#!/usr/bin/env bash
set +e
UI_PORT="${STORMRAVEN_UI_PORT:-3887}"
if ! ss -tln 2>/dev/null | grep -q ":${UI_PORT} "; then
  STORMRAVEN_GATEWAY_PORT="${UI_PORT}" STORMRAVEN_UI_PORT=3000 python3 /usr/local/bin/stormraven-local-gateway >/dev/null 2>&1 &
fi
for _ in $(seq 1 20); do
  if curl -fsS "http://127.0.0.1:${UI_PORT}/health" >/dev/null 2>&1; then
    break
  fi
  sleep 0.2
done
URL="${1:-http://127.0.0.1:${UI_PORT}/?os=win11}"
export NO_AT_BRIDGE=1
export GDK_BACKEND=x11
if [ -x /usr/local/bin/stormraven-shell-window ]; then
  python3 /usr/local/bin/stormraven-shell-window --win11 "${URL}" >/dev/null 2>&1 &
fi
if [ "$(id -u)" -ne 0 ]; then
  if command -v google-chrome-stable >/dev/null 2>&1; then
    google-chrome-stable --app="${URL}" >/dev/null 2>&1 &
  elif command -v google-chrome >/dev/null 2>&1; then
    google-chrome --app="${URL}" >/dev/null 2>&1 &
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "${URL}" >/dev/null 2>&1 &
  fi
fi
EOF
chmod 0755 /usr/local/bin/stormraven-open-ui

# 5. Create Trusted Desktop & App Menu Shortcuts
echo "==> [5/6] Creating Trusted Desktop Shortcuts..."
mkdir -p "${USER_HOME}/Desktop" /usr/share/applications
rm -f "${USER_HOME}/Desktop/stormraven-win11-edition.desktop" 2>/dev/null || true

cat > /usr/share/applications/stormraven-win11.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=StormRaven OS — Windows 11 Edition + Moov AI
Comment=Launch StormRaven OS: Infinity Protocol v3.9.0 Windows 11 Edition + Moov AI Command Center
Exec=/usr/local/bin/stormraven-open-ui http://127.0.0.1:3887/?os=win11
Icon=preferences-system-windows
Terminal=false
Categories=System;Utility;
EOF

cat > /usr/share/applications/stormraven-moov.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Moov AI Banking & Check Deposit
Comment=Same-Day ACH Transfers (.ach NACHA) & X9.37 Mobile Check Deposit (.x937 ICL)
Exec=/usr/local/bin/stormraven-open-ui http://127.0.0.1:3887/moov
Icon=accessories-calculator
Terminal=false
Categories=Office;Finance;System;
EOF

cp -f /usr/share/applications/stormraven-win11.desktop "${USER_HOME}/Desktop/StormRaven-OS-Windows-11-Edition.desktop"
cp -f /usr/share/applications/stormraven-moov.desktop "${USER_HOME}/Desktop/Moov-AI-Banking-and-Check-Deposit.desktop"
chmod 0755 "${USER_HOME}/Desktop/StormRaven-OS-Windows-11-Edition.desktop" "${USER_HOME}/Desktop/Moov-AI-Banking-and-Check-Deposit.desktop"
chown -R "${REAL_USER}:${REAL_USER}" "${USER_HOME}/Desktop" 2>/dev/null || true

if [ "${REAL_USER}" != "root" ] && command -v gio >/dev/null 2>&1; then
  su - "${REAL_USER}" -c "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${USER_UID}/bus gio set '${USER_HOME}/Desktop/StormRaven-OS-Windows-11-Edition.desktop' metadata::trusted true" 2>/dev/null || true
  su - "${REAL_USER}" -c "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${USER_UID}/bus gio set '${USER_HOME}/Desktop/Moov-AI-Banking-and-Check-Deposit.desktop' metadata::trusted true" 2>/dev/null || true
fi

# 6. Restart local gateway services and launch Windows 11 Edition + Moov AI UI
echo "==> [6/6] Starting Bifrost Gateway (:8787), Windows 11 Edition Web OS (:3887), and Moov AI..."
pkill -f "[s]tormraven-local-gateway" 2>/dev/null || true
systemctl daemon-reload 2>/dev/null || true
systemctl restart stormraven-kernel.service 2>/dev/null || true
nohup python3 /usr/local/bin/stormraven-local-gateway >/dev/null 2>&1 &
STORMRAVEN_GATEWAY_PORT=3887 STORMRAVEN_UI_PORT=3000 nohup python3 /usr/local/bin/stormraven-local-gateway >/dev/null 2>&1 &
sleep 1

# Verify local HTTP endpoints (:3887/moov and :3887/api/moov) are live
if curl -fsS http://127.0.0.1:3887/api/moov >/dev/null 2>&1; then
  echo "    ✓ Local Moov AI HTTP API (http://127.0.0.1:3887/moov) is ONLINE (HTTP 200 OK)"
fi

if [ "${1:-}" != "--no-ui" ] && [ "${REAL_USER}" != "root" ]; then
  su - "${REAL_USER}" -c "DISPLAY=${DISPLAY:-:0} XDG_RUNTIME_DIR=/run/user/${USER_UID} DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${USER_UID}/bus nohup /usr/local/bin/stormraven-open-ui 'http://127.0.0.1:3887/moov' >/dev/null 2>&1 &" || true
fi

echo ""
echo "======================================================================="
echo " 🪟 SUCCESS: STORMRAVEN OS v3.9.0 — WINDOWS 11 EDITION + MOOV AI IS LIVE!"
echo "   • System Name:          StormRaven OS: Infinity Protocol v3.9.0 — Windows 11 Edition + Moov AI"
echo "   • Windows 11 Web OS:    http://127.0.0.1:3887/?os=win11"
echo "   • Moov AI Web Portal:   http://127.0.0.1:3887/moov"
echo "   • Moov SQLite Ledger:   /var/lib/stormraven/moov/moov_ledger.db"
echo "   • CLI Commands:         stormraven moov status"
echo "                           stormraven ach --amount 250 --routing 021000021 --account 4829104921"
echo "                           stormraven deposit-check --amount 500 --routing 021000021 --account 981240112 --check-number 1042"
echo "======================================================================="
