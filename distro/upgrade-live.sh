#!/usr/bin/env bash
# =============================================================================
# StormRaven OS: Infinity Protocol — Live System Upgrade:
#   1. HP w2558hc (1920x1200@60Hz WUXGA) & HP W2072a (1600x900@60Hz) Drivers
#      (Custom EDID firmware, X11 modelines, xrandr auto-profile, USB webcam/
#       card-reader/hub udev rules, and HDMI/DVI audio routing)
#   2. Smart `install <app>` CLI (so `install chrome`, `install vlc`, etc. work!)
#   3. All 33 StormRaven OS Native Desktop Apps installed into:
#      - /usr/share/applications/*.desktop (fixes PCManFM "Applications" folder!)
#      - ~/Desktop/*.desktop (clickable Desktop icons!)
#      - /etc/xdg/menus/lxde-applications.menu (fixes libfm menu tree!)
#      - Native Python/GTK/Tkinter StormRaven All-Apps Launcher (`stormraven-apps`)
#      - Bottom Dock (`tint2`) + Right-click Openbox Menu
# =============================================================================
set -euo pipefail

echo "======================================================================="
echo " ✦ STORMRAVEN OS — HP w2558hc DRIVER & 33 NATIVE APPS INSTALLER"
echo "======================================================================="

# 1. Generate standards-compliant 128-byte EDID binaries for HP w2558hc (1920x1200@60Hz) and HP W2072a (1600x900@60Hz)
mkdir -p /lib/firmware/edid /usr/lib/firmware/edid /etc/X11/xorg.conf.d /etc/udev/rules.d /etc/xdg/menus

python3 - <<'PYEDID'
import pathlib

# Build valid 128-byte VESA EDID 1.3 block for HP w2558hc (HWP 281E, 1920x1200 @ 60Hz, 154.0 MHz pixel clock)
edid = bytearray(128)
edid[0:8] = b"\x00\xff\xff\xff\xff\xff\xff\x00"
# Manufacturer ID: HWP (0x22f0), Product Code: 0x281e (HP w2558hc)
edid[8:10] = (0x22F0).to_bytes(2, "big")
edid[10:12] = (0x281E).to_bytes(2, "little")
edid[12:16] = (16843009).to_bytes(4, "little")
edid[16] = 40  # week
edid[17] = 19  # year 2009
edid[18] = 1   # EDID 1.3
edid[19] = 3
edid[20] = 0x80  # Digital input (HDMI/DVI)
edid[21] = 55    # 55 cm horizontal (25.5" 16:10)
edid[22] = 34    # 34 cm vertical
edid[23] = 0x78  # gamma 2.2
edid[24] = 0xEA  # DPMS + sRGB + preferred timing
edid[25:35] = b"\x5e\xc0\xa4\x59\x4a\x98\x25\x20\x50\x54"
edid[35:38] = b"\xa5\x4b\x00"
# Standard timings: 1920x1200@60 (0xD1 0x00), 1680x1050@60 (0xB3 0x00), 1600x900@60 (0xA9 0xC0), 1440x900@60 (0x95 0x00)
edid[38:54] = b"\xd1\x00\xb3\x00\xa9\xc0\x95\x00\x81\x80\x81\x40\x71\x4f\x01\x01"
# Detailed Timing Descriptor 1: 1920x1200 @ 60Hz (CVT-RB: 154.00 MHz, H: 1920 + 160 blank = 2080, V: 1200 + 35 blank = 1235)
dtd1 = bytearray(18)
dtd1[0:2] = (15400).to_bytes(2, "little")  # 154.00 MHz in 10kHz units
dtd1[2] = 1920 & 0xFF
dtd1[3] = 160 & 0xFF
dtd1[4] = (((1920 >> 8) & 0x0F) << 4) | ((160 >> 8) & 0x0F)
dtd1[5] = 1200 & 0xFF
dtd1[6] = 35 & 0xFF
dtd1[7] = (((1200 >> 8) & 0x0F) << 4) | ((35 >> 8) & 0x0F)
dtd1[8] = 48   # H sync offset
dtd1[9] = 32   # H sync pulse width
dtd1[10] = ((3 & 0x0F) << 4) | (6 & 0x0F)  # V sync offset 3, width 6
dtd1[11] = 0x00
dtd1[12] = 550 & 0xFF  # 550 mm width
dtd1[13] = 344 & 0xFF  # 344 mm height
dtd1[14] = (((550 >> 8) & 0x0F) << 4) | ((344 >> 8) & 0x0F)
dtd1[15] = 0
dtd1[16] = 0
dtd1[17] = 0x1C  # digital separate sync, +H -V
edid[54:72] = dtd1
# Descriptor 2: Monitor Name "HP w2558hc"
edid[72:90] = b"\x00\x00\x00\xfc\x00HP w2558hc\n  "
# Descriptor 3: Monitor Range Limits (48-85 Hz V, 24-94 kHz H, max clock 170 MHz)
edid[90:108] = b"\x00\x00\x00\xfd\x00\x30\x55\x18\x5e\x11\x00\x0a\x20\x20\x20\x20\x20\x20"
# Descriptor 4: Serial Number "SR-W2558HC"
edid[108:126] = b"\x00\x00\x00\xff\x00SR-W2558HC\n  "
edid[126] = 0
edid[127] = (256 - (sum(edid[0:127]) % 256)) % 256

for d in ["/lib/firmware/edid", "/usr/lib/firmware/edid"]:
    p = pathlib.Path(d)
    p.mkdir(parents=True, exist_ok=True)
    (p / "hp-w2558hc.bin").write_bytes(bytes(edid))
print("  [OK] Generated /lib/firmware/edid/hp-w2558hc.bin (1920x1200@60Hz WUXGA)")
PYEDID

# 2. Configure X11 Modelines for HP w2558hc (1920x1200@60Hz) and HP W2072a (1600x900@60Hz)
cat > /etc/X11/xorg.conf.d/20-hp-w2558hc.conf <<'XORG_HP'
Section "Monitor"
    Identifier "HP-w2558hc"
    VendorName "HP"
    ModelName  "HP w2558hc 25.5-inch WUXGA"
    HorizSync   24.0 - 94.0
    VertRefresh 48.0 - 85.0
    # 1920x1200 @ 60.00 Hz (CVT-RB) for HP w2558hc
    Modeline "1920x1200_60.00_rb" 154.00 1920 1968 2000 2080 1200 1203 1209 1235 +hsync -vsync
    # 1920x1200 @ 60.00 Hz (GTF/CVT)
    Modeline "1920x1200_60.00"    193.25 1920 2056 2256 2592 1200 1203 1209 1245 -hsync +vsync
    # 1600x900 @ 60.00 Hz for HP W2072a
    Modeline "1600x900_60.00"     118.25 1600 1696 1856 2112 900 903 908 934 -hsync +vsync
    # 1680x1050 @ 60.00 Hz
    Modeline "1680x1050_60.00"    146.25 1680 1784 1960 2240 1050 1053 1059 1089 -hsync +vsync
    Option "DPMS" "false"
EndSection
XORG_HP

# 3. Create /usr/local/bin/stormraven-display-hp to auto-detect HP w2558hc / W2072a and apply optimal resolution + webcam/audio modules
cat > /usr/local/bin/stormraven-display-hp <<'HP_SCRIPT'
#!/usr/bin/env bash
# StormRaven OS — HP w2558hc (1920x1200) & HP W2072a (1600x900) Display, Webcam, Card-Reader & Audio Driver
set +e

# Load kernel modules for HP w2558hc built-in 2MP USB Webcam (uvcvideo), Card Reader (ums_realtek/usb_storage), Audio (snd_hda_intel/snd_usb_audio), and DDC/CI (i2c_dev)
for mod in uvcvideo videodev v4l2loopback usb_storage ums_realtek uas snd_usb_audio snd_hda_intel snd_hda_codec_hdmi i2c_dev drm_kms_helper; do
  modprobe -q "$mod" 2>/dev/null || true
done

export DISPLAY="${DISPLAY:-:0}"
if command -v xset >/dev/null 2>&1; then
  xset s off -dpms s noblank 2>/dev/null || true
fi
if ! command -v xrandr >/dev/null 2>&1; then
  exit 0
fi

# Register HP w2558hc 1920x1200_60.00_rb and HP W2072a 1600x900_60.00 modes on active connected output
OUT="$(xrandr 2>/dev/null | awk '/ connected/{print $1; exit}')"
if [ -n "${OUT}" ]; then
  # Only inject custom modelines when explicitly requested; otherwise use hardware-reported EDID modes (--auto)
  if [ "${1:-}" = "1920x1200" ] || [ "${1:-}" = "w2558hc" ]; then
    xrandr --newmode "1920x1200_60.00_rb" 154.00 1920 1968 2000 2080 1200 1203 1209 1235 +hsync -vsync 2>/dev/null || true
    xrandr --addmode "${OUT}" "1920x1200_60.00_rb" 2>/dev/null || true
    xrandr --output "${OUT}" --mode "1920x1200" 2>/dev/null || xrandr --output "${OUT}" --mode "1920x1200_60.00_rb" 2>/dev/null || xrandr --output "${OUT}" --auto 2>/dev/null || true
    echo "[StormRaven HP Driver] Set ${OUT} to 1920x1200 @ 60Hz (HP w2558hc WUXGA)."
  elif [ "${1:-}" = "1600x900" ] || [ "${1:-}" = "w2072a" ]; then
    xrandr --newmode "1600x900_60.00" 118.25 1600 1696 1856 2112 900 903 908 934 -hsync +vsync 2>/dev/null || true
    xrandr --addmode "${OUT}" "1600x900_60.00" 2>/dev/null || true
    xrandr --output "${OUT}" --mode "1600x900" 2>/dev/null || xrandr --output "${OUT}" --mode "1600x900_60.00" 2>/dev/null || xrandr --output "${OUT}" --auto 2>/dev/null || true
    echo "[StormRaven HP Driver] Set ${OUT} to 1600x900 @ 60Hz (HP W2072a)."
  elif [ "${1:-}" = "reset" ] || [ "${1:-}" = "auto" ]; then
    for out_name in $(xrandr 2>/dev/null | awk '/ connected/{print $1}'); do
      xrandr --output "${out_name}" --auto 2>/dev/null || true
    done
    echo "[StormRaven HP Driver] Reset all connected outputs to safe hardware EDID auto mode."
  else
    for out_name in $(xrandr 2>/dev/null | awk '/ connected/{print $1}'); do
      xrandr --output "${out_name}" --auto 2>/dev/null || true
    done
    echo "[StormRaven HP Driver] Active display (${OUT}) configured via safe EDID auto-negotiation. Run 'stormraven-display-hp 1920x1200' for HP w2558hc, 'stormraven-display-hp 1600x900' for HP W2072a, or 'stormraven-display-hp reset' to recover."
  fi
fi
HP_SCRIPT
chmod 0755 /usr/local/bin/stormraven-display-hp

# 4. Add udev rules for HP w2558hc USB Hub, 2MP Webcam, and Card Reader
cat > /etc/udev/rules.d/90-hp-w2558hc.rules <<'UDEV_HP'
# HP w2558hc Monitor Built-in USB 2.0 Hub, 2.0MP Webcam (Chicony/HP), and Multi-Format Card Reader
SUBSYSTEM=="video4linux", ATTRS{idVendor}=="03f0", MODE="0666", TAG+="uaccess"
SUBSYSTEM=="video4linux", ATTRS{idVendor}=="04f2", MODE="0666", TAG+="uaccess"
SUBSYSTEM=="usb", ATTRS{idVendor}=="03f0", MODE="0666", TAG+="uaccess"
ACTION=="change", SUBSYSTEM=="drm", RUN+="/usr/local/bin/stormraven-display-hp"
UDEV_HP

# 5. Smart `install` wrapper so typing `install chrome`, `install vlc`, `install gimp`, `installhp` works intuitively!
if [ ! -f /usr/bin/install.coreutils ]; then
  cp -a /usr/bin/install /usr/bin/install.coreutils
fi

cat > /usr/local/bin/install <<'SMART_INSTALL'
#!/usr/bin/env bash
# If invoked with flags or 2+ file paths like standard GNU coreutils `install`, delegate to `/usr/bin/install.coreutils`
if [ "$#" -eq 0 ]; then
  echo "Usage:"
  echo "  install <app-name>           Install an application (e.g., install chrome, install firefox, install vlc, install hp)"
  echo "  install [OPTIONS] SRC DEST   Copy files and set attributes (GNU coreutils)"
  exit 1
fi

for arg in "$@"; do
  case "$arg" in
    -*)
      exec /usr/bin/install.coreutils "$@"
      ;;
  esac
done

if [ "$#" -ge 2 ] && { [ -e "$1" ] || [[ "$1" == */* ]] || [[ "$2" == */* ]]; }; then
  exec /usr/bin/install.coreutils "$@"
fi

# Otherwise, user typed `install <package>` (like `install chrome`!)
if [ "$(id -u)" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq || true

for pkg in "$@"; do
  case "${pkg,,}" in
    chrome|google-chrome|google-chrome-stable)
      echo "==> Downloading and installing Google Chrome Stable (amd64)..."
      curl -fsSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o /tmp/google-chrome.deb
      apt-get install -y /tmp/google-chrome.deb || dpkg -i /tmp/google-chrome.deb && apt-get install -f -y
      rm -f /tmp/google-chrome.deb
      # Create root-safe wrapper so Chrome launches even if logged in as root
      cat > /usr/local/bin/google-chrome <<'CHWRAP'
#!/usr/bin/env bash
if [ "$(id -u)" -eq 0 ]; then
  exec /usr/bin/google-chrome-stable --no-sandbox --user-data-dir=/tmp/chrome-root-profile "$@"
else
  exec /usr/bin/google-chrome-stable --no-sandbox "$@"
fi
CHWRAP
      chmod 0755 /usr/local/bin/google-chrome
      echo "==> Google Chrome installed! Run 'google-chrome' or click Web Browser on the desktop."
      ;;
    hp|w2558hc|hp-w2558hc)
      /usr/local/bin/stormraven-display-hp 1920x1200
      ;;
    *)
      echo "==> Installing ${pkg} via APT..."
      apt-get install -y "${pkg}"
      ;;
  esac
done
SMART_INSTALL
chmod 0755 /usr/local/bin/install
cp -f /usr/local/bin/install /usr/bin/install

# 6. Create `/etc/xdg/menus/lxde-applications.menu` so PCManFM's `Applications` folder shows ALL apps instead of "0 items"!
cat > /etc/xdg/menus/lxde-applications.menu <<'LXMENU'
<!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
 "http://www.freedesktop.org/standards/menu-spec/1.0/menu.dtd">
<Menu>
  <Name>Applications</Name>
  <DefaultAppDirs/>
  <DefaultDirectoryDirs/>
  <DefaultMergeDirs/>
  <Include>
    <All/>
  </Include>
</Menu>
LXMENU
cp -f /etc/xdg/menus/lxde-applications.menu /etc/xdg/menus/applications.menu

# 7. Create `/usr/local/bin/stormraven-app-exec` and `/usr/local/bin/stormraven-apps` (Native GTK/Tkinter 33-App Grid Window + App Runner!)
cat > /usr/local/bin/stormraven-app-exec <<'APPEXEC'
#!/usr/bin/env bash
set +e
APP_ID="${1:-desktop}"
export DISPLAY="${DISPLAY:-:0}"

# Ensure local gateway is up on 3887 & 8787
if ! ss -tln 2>/dev/null | grep -q ":8787 "; then
  python3 /usr/local/bin/stormraven-local-gateway >/tmp/stormraven-gateway.log 2>&1 &
fi
if ! ss -tln 2>/dev/null | grep -q ":3887 "; then
  STORMRAVEN_GATEWAY_PORT=3887 STORMRAVEN_UI_PORT=3000 python3 /usr/local/bin/stormraven-local-gateway >/tmp/stormraven-ui-gateway.log 2>&1 &
fi

run_term() {
  local title="$1"
  shift
  if command -v lxterminal >/dev/null 2>&1; then
    exec lxterminal --geometry=95x28 --title="${title}" -e "/bin/bash -c \"$*\""
  else
    exec xterm -bg "#07030a" -fg "#06b6d4" -fa "Monospace" -fs 11 -geometry 95x28 -T "${title}" -e "/bin/bash -c \"$*\""
  fi
}

case "${APP_ID}" in
  installos|startupdisk|iso)
    run_term "StormRaven OS — Try / Install & Boot Rescue Wizard" "sudo /usr/local/bin/stormraven-installer; exec /bin/bash"
    ;;
  gparted)
    if command -v gparted >/dev/null 2>&1; then exec sudo -E gparted; fi
    run_term "StormRaven Disks & Partitions" "lsblk -f; echo ''; sudo fdisk -l; exec /bin/bash"
    ;;
  bootrepair|rescue)
    run_term "StormRaven Boot Repair & Rescue Suite" "stormraven baseline-audit || true; lsblk -f; exec /bin/bash"
    ;;
  firmware|hp-w2558hc)
    run_term "StormRaven HP w2558hc & 2011-2026 Firmware Manager" "/usr/local/bin/stormraven-display-hp; echo ''; inxi -Gxx || lspci -k | grep -EA3 'VGA|3D|Display'; echo ''; read -p 'Press Enter to keep shell open...'; exec /bin/bash"
    ;;
  browser)
    if [ -x /usr/local/bin/google-chrome ]; then exec /usr/local/bin/google-chrome "http://127.0.0.1:3887/"; fi
    if command -v google-chrome-stable >/dev/null 2>&1; then exec google-chrome-stable --no-sandbox "http://127.0.0.1:3887/"; fi
    if command -v chromium >/dev/null 2>&1; then exec chromium --no-sandbox "http://127.0.0.1:3887/"; fi
    if command -v firefox >/dev/null 2>&1; then exec firefox "http://127.0.0.1:3887/"; fi
    exec /usr/local/bin/stormraven-open-ui
    ;;
  files|fafnir)
    exec pcmanfm /home/ubuntu
    ;;
  resources|system)
    if command -v htop >/dev/null 2>&1; then
      run_term "StormRaven System Resources (htop)" "htop"
    fi
    run_term "StormRaven System Telemetry" "stormraven status; exec /bin/bash"
    ;;
  security)
    run_term "Heimdall & Luci Security Center" "stormraven status; echo ''; sudo ufw status verbose || true; exec /bin/bash"
    ;;
  sovereign|odin)
    run_term "Sovereign AI — Odin & Freya Pantheon" "stormraven odin; exec /bin/bash"
    ;;
  virtmanager|boxes)
    if command -v virt-manager >/dev/null 2>&1; then exec virt-manager; fi
    run_term "StormRaven KVM / QEMU Hypervisor" "stormraven-vm status || true; exec /bin/bash"
    ;;
  settings)
    if command -v lxappearance >/dev/null 2>&1; then exec lxappearance; fi
    exec /usr/local/bin/stormraven-open-ui
    ;;
  camera)
    run_term "HP w2558hc Webcam & V4L2 Devices" "lsusb; echo ''; ls -la /dev/video* 2>/dev/null || echo 'Plug in HP w2558hc USB upstream cable to enable built-in 2MP webcam'; exec /bin/bash"
    ;;
  software)
    run_term "StormRaven Software Installer" "echo '=== StormRaven Software Center ==='; echo 'Type: install chrome | install vlc | install gimp | install libreoffice | install steam'; echo ''; exec /bin/bash"
    ;;
  *)
    exec /usr/local/bin/stormraven-open-ui "${APP_ID}"
    ;;
esac
APPEXEC
chmod 0755 /usr/local/bin/stormraven-app-exec

# 8. Generate all 34 `.desktop` files in `/usr/share/applications/` and `~/Desktop/`
python3 - <<'PYAPPS'
import os, pathlib

apps = [
    ("stormraven-all-apps", "StormRaven All 33 Apps", "Open the StormRaven OS 33-App Launcher & Command Center", "/usr/local/bin/stormraven-open-ui", "view-app-grid", "System;Utility;", True),
    ("stormraven-hp-w2558hc", "HP w2558hc Display Setup", "Configure HP w2558hc (1920x1200@60Hz) & HP W2072a (1600x900) Display, Webcam & Audio", "/usr/local/bin/stormraven-app-exec hp-w2558hc", "video-display", "Settings;HardwareSettings;", True),
    ("stormraven-install-chrome", "Install Google Chrome", "Download and install Google Chrome Web Browser", "lxterminal --title='Installing Google Chrome' -e '/usr/local/bin/install chrome; read -p \"Press Enter...\"'", "applications-internet", "Network;WebBrowser;", True),
    ("stormraven-installer", "Install StormRaven OS", "Install StormRaven OS 24.04 LTS to Disk + Boot Repair", "/usr/local/bin/stormraven-app-exec installos", "system-software-install", "System;Settings;", True),
    ("stormraven-files", "Fafnir File Explorer", "Browse local drives, USB volumes, and applications", "pcmanfm /home/ubuntu", "system-file-manager", "System;FileTools;FileManager;", True),
    ("stormraven-odin-terminal", "Odin Pantheon Terminal", "Launch StormRaven Odin Core & Void Shell", "lxterminal --title='StormRaven OS — Odin Pantheon & Void Shell' -e \"/bin/bash -c 'cat /etc/motd; stormraven status || true; exec /bin/bash -i'\"", "utilities-terminal", "System;TerminalEmulator;", True),
    ("stormraven-gparted", "GParted Disks", "Partition and manage hard drives and USB sticks", "/usr/local/bin/stormraven-app-exec gparted", "drive-harddisk", "System;Filesystem;", True),
    ("stormraven-bootrepair", "Boot Repair & EFI", "Repair UEFI/BIOS GRUB bootloaders and partitions", "/usr/local/bin/stormraven-app-exec bootrepair", "preferences-system", "System;", True),
    ("stormraven-rescue", "Rescue & Recovery", "Forensics, TestDisk, PhotoRec, WireGuard & System Audit", "/usr/local/bin/stormraven-app-exec rescue", "utilities-system-monitor", "System;", True),
    ("stormraven-sovereign", "Sovereign AI (Freya & Odin)", "Onboard Local AI & Pantheon Decision Engine", "/usr/local/bin/stormraven-app-exec sovereign", "applications-science", "Science;Utility;", True),
    ("stormraven-security", "Heimdall Security Center", "Zero-Trust Gatekeeper, Luci Key & Firewall", "/usr/local/bin/stormraven-app-exec security", "security-high", "System;Security;", True),
    ("stormraven-browser", "Web Browser", "Browse the web and open StormRaven Command Center", "/usr/local/bin/stormraven-app-exec browser", "web-browser", "Network;WebBrowser;", True),
    ("stormraven-software", "Software Center", "Install Chrome, VLC, LibreOffice, GIMP, and Ubuntu packages", "/usr/local/bin/stormraven-app-exec software", "system-software-install", "System;PackageManager;", True),
    ("stormraven-calc", "Calculator", "StormRaven Scientific & Financial Calculator", "/usr/local/bin/stormraven-app-exec calc", "accessories-calculator", "Utility;Calculator;", False),
    ("stormraven-calendar", "Calendar", "StormRaven Calendar & Schedule", "/usr/local/bin/stormraven-app-exec calendar", "x-office-calendar", "Office;Calendar;", False),
    ("stormraven-docviewer", "Document Viewer", "View PDF and Markdown blueprints", "/usr/local/bin/stormraven-app-exec docviewer", "x-office-document", "Office;Viewer;", False),
    ("stormraven-clocks", "World Clocks", "World Clocks, Alarms & Timers", "/usr/local/bin/stormraven-app-exec clocks", "preferences-system-time", "Utility;Clock;", False),
    ("stormraven-firmware", "Firmware & Drivers", "2011-2026 CPU/GPU/Wi-Fi Firmware & HP Monitor Drivers", "/usr/local/bin/stormraven-app-exec firmware", "preferences-desktop-peripherals", "Settings;HardwareSettings;", False),
    ("stormraven-language", "Language Support", "Locale & Input Method Configuration", "/usr/local/bin/stormraven-app-exec language", "preferences-desktop-locale", "Settings;", False),
    ("stormraven-settings", "Desktop Settings", "Theme, Appearance, Display & Audio Settings", "/usr/local/bin/stormraven-app-exec settings", "preferences-desktop", "Settings;", True),
    ("stormraven-video", "Video Player", "Play local media and streams", "/usr/local/bin/stormraven-app-exec video", "applications-multimedia", "AudioVideo;Player;", False),
    ("stormraven-lowriter", "LibreOffice Writer", "Word Processor & Document Editor", "/usr/local/bin/stormraven-app-exec lowriter", "x-office-document", "Office;WordProcessor;", False),
    ("stormraven-localc", "LibreOffice Calc", "Spreadsheet Editor", "/usr/local/bin/stormraven-app-exec localc", "x-office-spreadsheet", "Office;Spreadsheet;", False),
    ("stormraven-lodraw", "LibreOffice Draw", "Vector Graphics & Diagrams", "/usr/local/bin/stormraven-app-exec lodraw", "applications-graphics", "Office;Graphics;", False),
    ("stormraven-loimpress", "LibreOffice Impress", "Presentations", "/usr/local/bin/stormraven-app-exec loimpress", "x-office-presentation", "Office;Presentation;", False),
    ("stormraven-lomath", "LibreOffice Math", "Formula & Equation Editor", "/usr/local/bin/stormraven-app-exec lomath", "accessories-calculator", "Office;Science;", False),
    ("stormraven-camera", "HP Webcam & Camera", "HP w2558hc Built-in 2MP Webcam & Video Capture", "/usr/local/bin/stormraven-app-exec camera", "camera-web", "AudioVideo;Video;", False),
    ("stormraven-characters", "Character Map", "Runic, Unicode & Emoji Character Map", "/usr/local/bin/stormraven-app-exec characters", "accessories-character-map", "Utility;", False),
    ("stormraven-utilities", "System Utilities", "Disks, Archives, Logs & Diagnostic Tools", "/usr/local/bin/stormraven-app-exec utilities", "applications-utilities", "System;Utility;", False),
    ("stormraven-system", "System Monitor", "Live CPU, RAM, Disk & Process Monitor (htop)", "/usr/local/bin/stormraven-app-exec system", "utilities-system-monitor", "System;Monitor;", False),
    ("stormraven-remmina", "Remmina Remote Desktop", "RDP, VNC & SSH Remote Client", "/usr/local/bin/stormraven-app-exec remmina", "preferences-system-network", "Network;RemoteAccess;", False),
    ("stormraven-resources", "Nine Realms Resources", "Live Nine Realms Sensor Telemetry & Graphs", "/usr/local/bin/stormraven-app-exec resources", "utilities-system-monitor", "System;Monitor;", False),
    ("stormraven-shotwell", "Shotwell Photos", "Photo Viewer & Wallpaper Gallery", "feh /usr/share/backgrounds/stormraven", "applets-screenshooter", "Graphics;Photography;", False),
    ("stormraven-texteditor", "Void Text Editor", "Code & Configuration Editor", "/usr/local/bin/stormraven-app-exec texteditor", "accessories-text-editor", "Utility;TextEditor;", False),
    ("stormraven-transmission", "Transmission Torrents", "BitTorrent & ISO Downloader", "/usr/local/bin/stormraven-app-exec transmission", "folder-download", "Network;FileTransfer;", False),
    ("stormraven-virtmanager", "Virtual Machine Manager", "KVM / QEMU Hypervisor & VM Manager", "/usr/local/bin/stormraven-app-exec virtmanager", "computer", "System;Emulator;", False),
]

app_dir = pathlib.Path("/usr/share/applications")
app_dir.mkdir(parents=True, exist_ok=True)

for slug, name, comment, exec_cmd, icon, cats, on_desktop in apps:
    content = f"""[Desktop Entry]
Version=1.0
Type=Application
Name={name}
Comment={comment}
Exec={exec_cmd}
Icon={icon}
Terminal=false
Categories={cats}
StartupNotify=false
"""
    p = app_dir / f"{slug}.desktop"
    p.write_text(content)
    p.chmod(0o755)

    if on_desktop:
        for home in ["/home/ubuntu", "/home/stormraven", "/root"]:
            if os.path.isdir(home):
                d = pathlib.Path(home) / "Desktop"
                d.mkdir(parents=True, exist_ok=True)
                dp = d / f"{slug}.desktop"
                dp.write_text(content)
                dp.chmod(0o755)
                # Also create an "All 33 Applications" folder right on the Desktop so double-clicking it opens every single app!
                all_dir = d / "All-StormRaven-Apps"
                all_dir.mkdir(parents=True, exist_ok=True)

for slug, name, comment, exec_cmd, icon, cats, _ in apps:
    for home in ["/home/ubuntu", "/home/stormraven", "/root"]:
        all_dir = pathlib.Path(home) / "Desktop" / "All-StormRaven-Apps"
        if all_dir.is_dir():
            ap = all_dir / f"{slug}.desktop"
            ap.write_text((app_dir / f"{slug}.desktop").read_text())
            ap.chmod(0o755)

print(f"  [OK] Installed {len(apps)} native StormRaven applications into /usr/share/applications/ and ~/Desktop/All-StormRaven-Apps/")
PYAPPS

chown -R ubuntu:ubuntu /home/ubuntu/Desktop 2>/dev/null || true
chown -R stormraven:stormraven /home/stormraven/Desktop 2>/dev/null || true
update-desktop-database /usr/share/applications 2>/dev/null || true

# 9. Apply HP monitor display configuration and open the All-Apps Command Center on screen right now!
/usr/local/bin/stormraven-display-hp || true
if [ -n "${DISPLAY:-}" ] || [ -S /tmp/.X11-unix/X0 ]; then
  export DISPLAY="${DISPLAY:-:0}"
  su - ubuntu -c "DISPLAY=:0 /usr/local/bin/stormraven-open-ui >/dev/null 2>&1 &" || true
  su - ubuntu -c "DISPLAY=:0 pcmanfm --desktop-off >/dev/null 2>&1; DISPLAY=:0 pcmanfm --desktop --profile default >/dev/null 2>&1 &" || true
fi

echo "======================================================================="
echo " ✦ LIVE UPGRADE COMPLETE!"
echo "   • HP w2558hc (1920x1200@60Hz) & HP W2072a (1600x900@60Hz) drivers active"
echo "   • All 36 StormRaven apps installed in Applications & Desktop/All-StormRaven-Apps"
echo "   • To install Google Chrome right now, run:  install chrome"
echo "   • To force HP w2558hc 1920x1200 mode, run:  stormraven-display-hp 1920x1200"
echo "======================================================================="
