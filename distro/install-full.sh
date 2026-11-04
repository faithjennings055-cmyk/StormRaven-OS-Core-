#!/usr/bin/env bash
# =============================================================================
# StormRaven OS: Infinity Protocol v3.9.0 "All-Father" — Full Decked-Out Suite
# =============================================================================
# Installs every single StormRaven OS bell and whistle onto either:
#   A) Your current running Ubuntu Desktop / StormRaven Live session, OR
#   B) Directly onto a target bare-metal disk (--install-disk /dev/sdX)
#
# Includes:
#   • StormRaven Kernel + Bifrost Gateway (:8787 & :3887) + Systemd Daemon
#   • Odin Python Pantheon (Odin, Thor, Freya, Heimdall, Luci, Solomon, Heketa, Lynn)
#   • Runic Command Gatekeeper (`fehu`, `algiz`, `isa`, `raido`)
#   • Ymir Edition 3-Panel Cryo-Glass HUD & Dark GTK/Openbox Theme + Tint2 Dock
#   • All 36 Native Desktop Applications (/usr/share/applications + ~/Desktop)
#   • Full Productivity & Media Suite: Google Chrome, VLC, GIMP, LibreOffice,
#     Remmina, Shotwell, Transmission, Evince, Galculator, GParted, Htop
#   • Built-in KVM/QEMU Hypervisor (`virt-manager`, `qemu-system-x86`, `libvirt`)
#   • Built-in WireGuard VPN + UFW Kill-Switch (`stormraven-vpn`)
#   • Built-in Digital Forensics & Boot Rescue (`testdisk`, `sleuthkit`, `binwalk`,
#     `yara`, `foremost`, `smartmontools`, `nvme-cli`, `efibootmgr`, `timeshift`)
#   • HP w2558hc (1920x1200@60Hz) & HP W2072a (1600x900@60Hz) Display, Webcam,
#     Card-Reader & HDMI/DVI Audio Driver Suite (`stormraven-display-hp`)
#   • Authenticated HMAC-SHA256 Mobile Cloud Bridge (`stormraven-cloud-bridge`)
# =============================================================================
set -euo pipefail

CLOUD_URL="https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app"
VERSION="3.9.0"

if [ "$(id -u)" -ne 0 ]; then
  exec sudo -E bash "$0" "$@"
fi

echo "======================================================================="
echo " ✦ STORMRAVEN OS v${VERSION} — FULL DECKED-OUT ALL-FATHER INSTALLER"
echo "   Every Bell & Whistle · Moov AI ACH/mRDC · 37 Apps · Ymir HUD · Drivers"
echo "======================================================================="

export DEBIAN_FRONTEND=noninteractive

# 1. Install StormRaven OS .deb package (Kernel, Pantheon, CLI, Systemd Services)
echo "==> [1/7] Installing StormRaven OS Core Package (stormraven-os_${VERSION}_amd64.deb)..."
curl -fsSL "${CLOUD_URL}/iso/stormraven-os_${VERSION}_amd64.deb" -o /tmp/stormraven-os.deb
curl -fsSL "${CLOUD_URL}/iso/stormraven-os_${VERSION}_amd64.deb.sha256" -o /tmp/stormraven-os.deb.sha256
(cd /tmp && sed -i "s|stormraven-os_${VERSION}_amd64.deb|stormraven-os.deb|g" stormraven-os.deb.sha256 && sha256sum -c stormraven-os.deb.sha256)
dpkg -i /tmp/stormraven-os.deb || apt-get install -f -y -qq
rm -f /tmp/stormraven-os.deb /tmp/stormraven-os.deb.sha256

# 2. Install Full Desktop, Office, Media, Hypervisor, VPN, Forensics & Rescue Packages
echo "==> [2/7] Installing Full Desktop, Media, Office, KVM, VPN & Forensic Suite..."
apt-get update -qq || true

CORE_PKGS=(
  curl wget git rsync jq sqlite3 python3 python-is-python3 python3-rich python3-psutil
  xorg x11-xserver-utils openbox tint2 pcmanfm lxterminal lxappearance feh scrot
  papirus-icon-theme adwaita-icon-theme fonts-noto-color-emoji librsvg2-common
  htop inxi lshw pciutils usbutils net-tools iproute2 ufw wireguard-tools
  parted gdisk fdisk dosfstools ntfs-3g exfatprogs btrfs-progs lvm2 cryptsetup
  efibootmgr grub-efi-amd64-bin grub-pc-bin os-prober smartmontools nvme-cli
  testdisk gddrescue timeshift
)
apt-get install -y --no-install-recommends "${CORE_PKGS[@]}" 2>/dev/null || true

EXTRA_APPS=(
  gparted vlc gimp libreoffice-writer libreoffice-calc libreoffice-impress
  libreoffice-draw libreoffice-math remmina shotwell transmission-gtk
  evince galculator gnome-calendar gnome-clocks gnome-characters
  virt-manager qemu-system-x86 libvirt-daemon-system sleuthkit binwalk yara foremost
)
if [ "${SKIP_HEAVY_APT:-0}" != "1" ]; then
  echo "    Installing native GUI applications (GParted, VLC, GIMP, LibreOffice, Remmina, Virt-Manager, Forensics)..."
  apt-get install -y --no-install-recommends "${EXTRA_APPS[@]}" 2>/dev/null || true
fi

# 3. Install Google Chrome Stable (if not already installed)
echo "==> [3/7] Ensuring Google Chrome Stable is installed..."
if ! command -v google-chrome-stable >/dev/null 2>&1; then
  if curl -fsSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o /tmp/google-chrome.deb; then
    apt-get install -y /tmp/google-chrome.deb 2>/dev/null || (dpkg -i /tmp/google-chrome.deb && apt-get install -f -y -qq) || true
    rm -f /tmp/google-chrome.deb
  fi
fi

# 4. Run HP w2558hc / W2072a Driver + 36 Native Desktop Apps + Smart `install` CLI Setup
echo "==> [4/7] Configuring HP w2558hc / W2072a Monitor Drivers & All 36 Native Apps..."
curl -fsSL "${CLOUD_URL}/upgrade-live.sh" -o /tmp/upgrade-live.sh
curl -fsSL "${CLOUD_URL}/upgrade-live.sh.sha256" -o /tmp/upgrade-live.sh.sha256
(cd /tmp && sha256sum -c upgrade-live.sh.sha256)
bash /tmp/upgrade-live.sh
rm -f /tmp/upgrade-live.sh /tmp/upgrade-live.sh.sha256

# 5. Apply Ymir Edition Cryo-Glass HUD, Dark GTK/Openbox Theme, Runes & Cloud Bridge
echo "==> [5/7] Applying Ymir Edition Cryo-Glass 3-Panel HUD, Runes & Mobile Bridge..."
curl -fsSL "${CLOUD_URL}/upgrade-void.sh" -o /tmp/upgrade-void.sh
curl -fsSL "${CLOUD_URL}/upgrade-void.sh.sha256" -o /tmp/upgrade-void.sh.sha256
(cd /tmp && sha256sum -c upgrade-void.sh.sha256)
bash /tmp/upgrade-void.sh
rm -f /tmp/upgrade-void.sh /tmp/upgrade-void.sh.sha256

# 6. Enable & Start StormRaven Kernel + Desktop UI Services
echo "==> [6/7] Verifying StormRaven Kernel, Bifrost Gateway (:8787 / :3887) & Pantheon..."
systemctl daemon-reload 2>/dev/null || true
systemctl enable --now stormraven-kernel.service 2>/dev/null || true
if ! ss -tln 2>/dev/null | grep -q ":8787 "; then
  nohup python3 /usr/local/bin/stormraven-local-gateway >/tmp/stormraven-gateway.log 2>&1 &
fi

# 7. Optional Bare-Metal Disk Installation if `--install-disk /dev/sdX` was passed
if [ "${1:-}" = "--install-disk" ] && [ -n "${2:-}" ]; then
  echo "==> [7/7] Launching Bare-Metal Disk Installation onto ${2}..."
  /usr/local/bin/stormraven-installer --install-disk "${2}" "${3:-stormraven}" "${4:-stormraven}" "${5:-Stormraven}"
else
  echo "==> [7/7] Full Decked-Out Setup Complete!"
fi

echo ""
echo "======================================================================="
echo " ✦ STORMRAVEN OS v${VERSION} (ALL-FATHER EDITION) IS LIVE & DECKED OUT!"
echo "   • Moov AI Banking:      stormraven moov status | stormraven ach | stormraven deposit-check"
echo "   • 37 Native Apps:       Desktop/All-StormRaven-Apps & Applications Menu"
echo "   • Ymir 3-Panel HUD:     http://127.0.0.1:3887/ (and /moov Check Deposit UI)"
echo "   • Runic Commands:       fehu  |  algiz  |  isa  |  raido"
echo "   • Smart App Installer:  install chrome | install vlc | install steam"
echo "   • HP Monitor Driver:    stormraven-display-hp (auto EDID)"
echo "   • Install OS to Disk:   sudo stormraven-installer"
echo "   • Flash Live USB Stick: curl -fsSL ${CLOUD_URL}/flash-usb.sh | sudo bash"
echo "======================================================================="
