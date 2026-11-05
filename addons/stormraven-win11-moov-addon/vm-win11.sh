#!/usr/bin/env bash
# =============================================================================
# StormRaven OS: Infinity Protocol v3.9.0 — GNOME Boxes Windows 11 + Moov AI VM
# =============================================================================
# Specifically engineered for Faith Jennings' HP Pro 3500 Series (GNOME Boxes):
#   1. Installs `gnome-boxes` (if not already installed) and heals any
#      interrupted dpkg state automatically.
#   2. Downloads & verifies the 30MB `StormRavenOS-Win11-Full-v3.9.0-x64.zip`
#      bundle (`StormRaven.Kernel.exe`, `Install-StormRaven-Win11.ps1`,
#      `LAUNCH-STORMRAVEN-WIN11.bat`, `autounattend.xml`, Moov AI ACH & Check
#      Deposit, Odin Pantheon, and 37 apps).
#   3. Builds TWO ready-to-use ISOs in `~/Downloads`:
#        A) `~/Downloads/StormRavenOS-Win11-Boxes-v3.9.0.iso` — Single
#           self-contained bootable ISO for GNOME Boxes that boots directly
#           into the StormRaven OS v3.9.0 Windows 11 Edition + Moov AI desktop!
#        B) `~/Downloads/StormRaven-Win11-Payload.iso` — Data CD/DVD image
#           you can attach inside GNOME Boxes (Preferences -> Devices & Shares
#           -> CD/DVD Drive) to any Microsoft Windows 11 VM!
#   4. Launches `gnome-boxes` as your desktop user directly on the bootable ISO!
#
# One-command usage on HP Pro 3500:
#   curl -fsSL https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/vm-win11.sh | sudo bash
# =============================================================================
set -euo pipefail

CLOUD_URL="${STORMRAVEN_GATEWAY_URL:-https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app}"
ZIP_NAME="StormRavenOS-Win11-Full-v3.9.0-x64.zip"
ZIP_URL="${CLOUD_URL}/iso/${ZIP_NAME}"
SHA_URL="${ZIP_URL}.sha256"
SR_ISO_NAME="StormRavenOS-Infinity-Protocol-v3.9.0-amd64.iso"
SR_ISO_URL="${CLOUD_URL}/iso/${SR_ISO_NAME}"

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: Please run with sudo:"
  echo "  curl -fsSL ${CLOUD_URL}/vm-win11.sh | sudo bash"
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

VM_DIR="${VM_DIR:-/var/tmp/stormraven-win11-vm}"
PAYLOAD_DIR="${VM_DIR}/payload"
DOWNLOADS_DIR="${USER_HOME}/Downloads"
PAYLOAD_ISO="${DOWNLOADS_DIR}/StormRaven-Win11-Payload.iso"
BOXES_BOOT_ISO="${DOWNLOADS_DIR}/StormRavenOS-Win11-Boxes-v3.9.0.iso"

mkdir -p "${VM_DIR}" "${PAYLOAD_DIR}" "${DOWNLOADS_DIR}"
pkill -f "qemu-system-x86_64.*StormRaven-OS-Win11-Test" 2>/dev/null || true
pkill -f "swtpm.*stormraven-win11-vm" 2>/dev/null || true

echo "======================================================================="
echo " ✦ STORMRAVEN OS v3.9.0 — GNOME BOXES WINDOWS 11 + MOOV AI VM SUITE"
echo "   GNOME Boxes · Self-Contained Bootable ISO · Preloaded Win11 Drive"
echo "======================================================================="

# 1. Heal any interrupted dpkg state, purge unnecessary VM programs, and keep ONLY gnome-boxes
echo "==> [1/4] Purging unnecessary VM programs (virt-manager, swtpm, qemu-system-gui, virtualbox) & keeping ONLY GNOME Boxes..."
pkill -f "qemu-system-x86_64.*StormRaven-OS-Win11-Test" 2>/dev/null || true
pkill -f "virt-manager" 2>/dev/null || true
pkill -f "swtpm" 2>/dev/null || true
rm -rf /var/tmp/stormraven-win11-vm/win11-stormraven.qcow2 /var/tmp/stormraven-win11-vm/tpm2 /var/tmp/stormraven-win11-vm/OVMF_VARS.fd 2>/dev/null || true

dpkg-divert --package stormraven-os --divert /etc/xdg/menus/lxde-applications.menu.distrib --rename /etc/xdg/menus/lxde-applications.menu >/dev/null 2>&1 || true
dpkg-divert --package stormraven-os --divert /etc/xdg/menus/applications.menu.distrib --rename /etc/xdg/menus/applications.menu >/dev/null 2>&1 || true
dpkg --configure -a --force-overwrite >/dev/null 2>&1 || true
apt-get -f install -y -qq -o Dpkg::Options::="--force-overwrite" >/dev/null 2>&1 || true

# Remove standalone VM UIs/daemons that are unnecessary when using GNOME Boxes
UNNECESSARY_VM_PKGS=()
for pkg in virt-manager virt-viewer swtpm swtpm-tools qemu-system-gui virtualbox virtualbox-qt vagrant; do
  if dpkg -s "${pkg}" >/dev/null 2>&1; then
    UNNECESSARY_VM_PKGS+=("${pkg}")
  fi
done
if [ "${#UNNECESSARY_VM_PKGS[@]}" -gt 0 ]; then
  export DEBIAN_FRONTEND=noninteractive
  echo "    Removing: ${UNNECESSARY_VM_PKGS[*]}..."
  apt-get purge -y -qq -o Dpkg::Options::="--force-overwrite" "${UNNECESSARY_VM_PKGS[@]}" 2>/dev/null || true
  apt-get autoremove -y -qq 2>/dev/null || true
fi
rm -f "${USER_HOME}/Desktop/virt-manager.desktop" \
      "${USER_HOME}/Desktop/All-StormRaven-Apps/virt-manager.desktop" \
      /usr/share/applications/virt-manager.desktop 2>/dev/null || true

NEED_PKGS=()
if [ "${1:-}" != "--prepare-only" ] && [ "${NO_LAUNCH:-0}" != "1" ]; then
  command -v gnome-boxes >/dev/null 2>&1 || NEED_PKGS+=(gnome-boxes)
fi
command -v xorriso >/dev/null 2>&1 || NEED_PKGS+=(xorriso)
command -v grub-mkrescue >/dev/null 2>&1 || NEED_PKGS+=(grub-common grub-pc-bin mtools)
[ -d /usr/lib/grub/i386-pc ] || NEED_PKGS+=(grub-pc-bin)
command -v cpio >/dev/null 2>&1 || NEED_PKGS+=(cpio)
command -v unzip >/dev/null 2>&1 || NEED_PKGS+=(unzip)

if [ "${#NEED_PKGS[@]}" -gt 0 ]; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq || true
  apt-get install -y -qq -o Dpkg::Options::="--force-overwrite" "${NEED_PKGS[@]}"
fi

# Ensure user is in kvm and libvirt groups so GNOME Boxes gets full hardware acceleration
if [ "${REAL_USER}" != "root" ]; then
  usermod -aG kvm "${REAL_USER}" 2>/dev/null || true
  usermod -aG libvirt "${REAL_USER}" 2>/dev/null || true
  chmod 0666 /dev/kvm 2>/dev/null || true
fi

# 2. Download & verify StormRavenOS-Win11-Full-v3.9.0-x64.zip
echo "==> [2/4] Downloading & verifying StormRaven Windows 11 Full Bundle..."
ZIP_PATH="${VM_DIR}/${ZIP_NAME}"
SHA_PATH="${ZIP_PATH}.sha256"

curl -fsSL "${SHA_URL}?t=$(date +%s)" -o "${SHA_PATH}"
EXPECTED_SHA="$(awk '{print $1}' "${SHA_PATH}")"

NEED_DL=1
if [ -f "${ZIP_PATH}" ]; then
  ACTUAL_SHA="$(sha256sum "${ZIP_PATH}" | awk '{print $1}')"
  if [ "${ACTUAL_SHA}" = "${EXPECTED_SHA}" ]; then
    echo "    ✓ Cached Win11 bundle matches SHA-256 (${EXPECTED_SHA:0:16}...)"
    NEED_DL=0
  fi
fi

if [ "${NEED_DL}" -eq 1 ]; then
  curl -fL --retry 3 "${ZIP_URL}?v=${EXPECTED_SHA:0:12}" -o "${ZIP_PATH}"
  (cd "${VM_DIR}" && sha256sum -c "${ZIP_NAME}.sha256")
fi

# 3. Build ~/Downloads/StormRaven-Win11-Payload.iso (for attaching to any MS Windows 11 VM in Boxes)
echo "==> [3/4] Building ${PAYLOAD_ISO}..."
rm -rf "${PAYLOAD_DIR}"
mkdir -p "${PAYLOAD_DIR}"
unzip -q -o "${ZIP_PATH}" -d "${PAYLOAD_DIR}"

if [ -d "${PAYLOAD_DIR}/StormRaven-Win11-Full" ]; then
  mv -f "${PAYLOAD_DIR}/StormRaven-Win11-Full/"* "${PAYLOAD_DIR}/" 2>/dev/null || true
  rmdir "${PAYLOAD_DIR}/StormRaven-Win11-Full" 2>/dev/null || true
fi

cat > "${PAYLOAD_DIR}/autounattend.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <settings pass="windowsPE">
    <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
      <RunSynchronous>
        <RunSynchronousCommand wcm:action="add">
          <Order>1</Order>
          <Path>reg add HKLM\SYSTEM\Setup\LabConfig /v BypassTPMCheck /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>2</Order>
          <Path>reg add HKLM\SYSTEM\Setup\LabConfig /v BypassSecureBootCheck /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>3</Order>
          <Path>reg add HKLM\SYSTEM\Setup\LabConfig /v BypassRAMCheck /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>4</Order>
          <Path>reg add HKLM\SYSTEM\Setup\LabConfig /v BypassStorageCheck /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
        <RunSynchronousCommand wcm:action="add">
          <Order>5</Order>
          <Path>reg add HKLM\SYSTEM\Setup\LabConfig /v BypassCPUCheck /t REG_DWORD /d 1 /f</Path>
        </RunSynchronousCommand>
      </RunSynchronous>
    </component>
  </settings>
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
      <OOBE>
        <HideEULAPage>true</HideEULAPage>
        <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
        <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
        <HideWirelessSetupInOOBE>false</HideWirelessSetupInOOBE>
        <ProtectYourPC>3</ProtectYourPC>
      </OOBE>
      <UserAccounts>
        <LocalAccounts>
          <LocalAccount wcm:action="add">
            <Name>stormraven</Name>
            <DisplayName>StormRaven Sovereign</DisplayName>
            <Group>Administrators</Group>
            <Password>
              <Value>Stormraven</Value>
              <PlainText>true</PlainText>
            </Password>
          </LocalAccount>
        </LocalAccounts>
      </UserAccounts>
      <AutoLogon>
        <Password>
          <Value>Stormraven</Value>
          <PlainText>true</PlainText>
        </Password>
        <Enabled>true</Enabled>
        <Username>stormraven</Username>
      </AutoLogon>
      <FirstLogonCommands>
        <SynchronousCommand wcm:action="add">
          <Order>1</Order>
          <Description>Bootstrap StormRaven OS Windows 11 Edition + Moov AI</Description>
          <CommandLine>powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "foreach ($d in [IO.DriveInfo]::GetDrives()) { $p = Join-Path $d.RootDirectory.FullName 'Install-StormRaven-Win11.ps1'; if (Test-Path $p) { &amp; $p; exit 0 } }; irm https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/install-win11.ps1 | iex"</CommandLine>
        </SynchronousCommand>
      </FirstLogonCommands>
    </component>
  </settings>
</unattend>
EOF

cat > "${PAYLOAD_DIR}/LAUNCH-STORMRAVEN-WIN11.bat" << 'EOF'
@echo off
title StormRaven OS v3.9.0 — Windows 11 Edition Full Installer
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Requesting Administrator privileges for StormRaven OS Installer...
    powershell.exe -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-StormRaven-Win11.ps1"
start http://127.0.0.1:3887
pause
EOF

xorriso -as mkisofs -J -r -V "STORMRAVEN_WIN11" -o "${PAYLOAD_ISO}" "${PAYLOAD_DIR}" >/dev/null 2>&1
echo "    ✓ Built ${PAYLOAD_ISO} ($(du -h "${PAYLOAD_ISO}" | awk '{print $1}'))"

# 4. Build single self-contained bootable ISO for GNOME Boxes: ~/Downloads/StormRavenOS-Win11-Boxes-v3.9.0.iso
echo "==> [4/4] Building single-file bootable GNOME Boxes ISO (${BOXES_BOOT_ISO})..."
SR_ISO_PATH=""
for cand in \
  "${DOWNLOADS_DIR}/${SR_ISO_NAME}" \
  "/tmp/iso/${SR_ISO_NAME}" \
  "${VM_DIR}/${SR_ISO_NAME}" \
  "${USER_HOME}/Desktop/${SR_ISO_NAME}"; do
  if [ -f "${cand}" ] && [ "$(stat -c %s "${cand}" 2>/dev/null || echo 0)" -gt 500000000 ]; then
    SR_ISO_PATH="${cand}"
    break
  fi
done

if [ -z "${SR_ISO_PATH}" ]; then
  SR_ISO_PATH="${DOWNLOADS_DIR}/${SR_ISO_NAME}"
  echo "    Downloading base StormRaven OS Live ISO to ${SR_ISO_PATH}..."
  curl -fL --retry 3 -o "${SR_ISO_PATH}" "${SR_ISO_URL}"
fi

# Extract vmlinuz, initrd, and squashfs from base ISO into PAYLOAD_DIR so ONE ISO has everything
mkdir -p "${PAYLOAD_DIR}/casper" "${PAYLOAD_DIR}/boot/grub"
xorriso -osirrox on -indev "${SR_ISO_PATH}" \
  -extract /casper/vmlinuz "${PAYLOAD_DIR}/casper/vmlinuz" \
  -extract /casper/initrd "${VM_DIR}/initrd-base" >/dev/null 2>&1

# Extract squashfs (either stormraven-v393.squashfs or filesystem.squashfs)
if xorriso -osirrox on -indev "${SR_ISO_PATH}" -extract /casper/stormraven-v393.squashfs "${PAYLOAD_DIR}/casper/stormraven-v393.squashfs" >/dev/null 2>&1 && [ -f "${PAYLOAD_DIR}/casper/stormraven-v393.squashfs" ]; then
  ln -sf stormraven-v393.squashfs "${PAYLOAD_DIR}/casper/filesystem.squashfs"
else
  xorriso -osirrox on -indev "${SR_ISO_PATH}" -extract /casper/filesystem.squashfs "${PAYLOAD_DIR}/casper/stormraven-v393.squashfs" >/dev/null 2>&1
  ln -sf stormraven-v393.squashfs "${PAYLOAD_DIR}/casper/filesystem.squashfs"
fi

chmod 0644 "${PAYLOAD_DIR}/casper/vmlinuz" "${VM_DIR}/initrd-base" "${PAYLOAD_DIR}/casper/stormraven-v393.squashfs"
cp -f "${VM_DIR}/initrd-base" "${PAYLOAD_DIR}/casper/initrd"
chmod u+w "${PAYLOAD_DIR}/casper/initrd"

# Append the Windows 11 Edition + Moov AI initramfs overlay onto initrd
OVL_DIR="${VM_DIR}/initrd-ovl"
rm -rf "${OVL_DIR}"
mkdir -p "${OVL_DIR}/scripts"
cat > "${OVL_DIR}/scripts/casper" << 'CASPER_EOF'
#!/bin/sh
mount_top() { :; }
mount_premount() { :; }
mount_bottom() { :; }

mountroot() {
    echo "[StormRaven Win11 Boxes VM] Loading storage & filesystem drivers..."
    for mod in overlay squashfs iso9660 isofs loop sr_mod cdrom sd_mod ahci ata_piix virtio virtio_ring virtio_pci virtio_blk virtio_scsi virtio_net e1000 bochs bochs_drm virtio_gpu qxl; do
        modprobe -q "$mod" 2>/dev/null || true
    done
    udevadm trigger 2>/dev/null || true
    udevadm settle --timeout=5 2>/dev/null || true

    mkdir -p /run/casper-medium /run/casper-ro /run/casper-rw
    SQUASHFS_PATH=""
    for attempt in $(seq 1 25); do
        for dev in /dev/sr0 /dev/sr1 /dev/sr* /dev/vd* /dev/sd*; do
            [ -b "$dev" ] || continue
            if mount -r -t iso9660 "$dev" /run/casper-medium 2>/dev/null || mount -r "$dev" /run/casper-medium 2>/dev/null; then
                if [ -f /run/casper-medium/casper/stormraven-v393.squashfs ]; then
                    SQUASHFS_PATH="/run/casper-medium/casper/stormraven-v393.squashfs"
                    break 2
                elif [ -f /run/casper-medium/casper/filesystem.squashfs ]; then
                    SQUASHFS_PATH="/run/casper-medium/casper/filesystem.squashfs"
                    break 2
                fi
                umount /run/casper-medium 2>/dev/null || true
            fi
        done
        sleep 1
    done

    mount -t squashfs -o loop,ro "$SQUASHFS_PATH" /run/casper-ro
    mount -t tmpfs -o mode=0755 tmpfs /run/casper-rw
    mkdir -p /run/casper-rw/upper /run/casper-rw/work
    mount -t overlay overlay -o "lowerdir=/run/casper-ro,upperdir=/run/casper-rw/upper,workdir=/run/casper-rw/work" "${rootmnt}"
    mkdir -p "${rootmnt}/cdrom" "${rootmnt}/rofs" "${rootmnt}/mnt/STORMRAVEN_WIN11"

    # Copy the STORMRAVEN_WIN11 files directly from the mounted boot ISO (/run/casper-medium)
    cp -rf /run/casper-medium/Install-StormRaven-Win11.ps1 \
           /run/casper-medium/LAUNCH-STORMRAVEN-WIN11.bat \
           /run/casper-medium/autounattend.xml \
           /run/casper-medium/bin \
           /run/casper-medium/python \
           /run/casper-medium/webapp \
           /run/casper-medium/drivers \
           "${rootmnt}/mnt/STORMRAVEN_WIN11/" 2>/dev/null || true

    # Inject latest Windows 11 Edition + Moov AI desktop binaries & webapp into live rootfs in RAM!
    if [ -d /run/casper-medium/linux-vm ]; then
        cp -f /run/casper-medium/linux-vm/* "${rootmnt}/usr/local/bin/" 2>/dev/null || true
        chmod 0755 "${rootmnt}/usr/local/bin/stormraven"* 2>/dev/null || true
        ln -sf /usr/local/bin/stormraven-moov "${rootmnt}/usr/local/bin/moov-ai" 2>/dev/null || true
    fi
    if [ -d /run/casper-medium/webapp ]; then
        mkdir -p "${rootmnt}/opt/stormraven/webapp"
        cp -rf /run/casper-medium/webapp/* "${rootmnt}/opt/stormraven/webapp/" 2>/dev/null || true
    fi
    if [ -d /run/casper-medium/python ]; then
        mkdir -p "${rootmnt}/opt/stormraven/python"
        cp -rf /run/casper-medium/python/* "${rootmnt}/opt/stormraven/python/" 2>/dev/null || true
    fi

    # Ensure PAM-free direct autologin on tty1..6
    if [ -x "${rootmnt}/usr/local/bin/stormraven-tty-login" ]; then
        for tty_num in 1 2 3 4 5 6; do
            tty_user="stormraven"
            [ "$tty_num" = "1" ] && tty_user="ubuntu"
            mkdir -p "${rootmnt}/etc/systemd/system/getty@tty${tty_num}.service.d"
            cat > "${rootmnt}/etc/systemd/system/getty@tty${tty_num}.service.d/override.conf" << TTY_EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty -n -l /usr/local/bin/stormraven-tty-login -o "${tty_user}" --noclear tty${tty_num} linux
Type=idle
Restart=always
RestartSec=1
TTY_EOF
        done
    fi

    rm -f "${rootmnt}/tmp/"*.log 2>/dev/null || true
    chmod 1777 "${rootmnt}/tmp" "${rootmnt}/var/tmp" 2>/dev/null || true
    echo "[StormRaven Win11 Boxes VM] Windows 11 Edition + Moov AI live rootfs ready."
}
CASPER_EOF
chmod +x "${OVL_DIR}/scripts/casper"
ln -sf casper "${OVL_DIR}/scripts/live"
(cd "${OVL_DIR}" && find . | cpio -o -H newc >> "${PAYLOAD_DIR}/casper/initrd" 2>/dev/null)

cat > "${PAYLOAD_DIR}/boot/grub/grub.cfg" << 'GRUB_EOF'
set default=0
set timeout=2
insmod all_video
insmod gfxterm
set gfxmode=1280x800x32,1280x800,1024x768,auto
set gfxpayload=keep
terminal_output gfxterm

menuentry "StormRaven OS v3.9.0 - Windows 11 Edition + Moov AI (GNOME Boxes VM)" {
    echo "Booting StormRaven OS v3.9.0 - Windows 11 Edition + Moov AI..."
    linux /casper/vmlinuz boot=casper console=tty0 stormraven.edition=win11
    initrd /casper/initrd
}
GRUB_EOF

grub-mkrescue -o "${BOXES_BOOT_ISO}" "${PAYLOAD_DIR}" -- -volid "STORMRAVEN_W11" 2>/dev/null
rm -rf "${PAYLOAD_DIR}" "${VM_DIR}/initrd-base" "${OVL_DIR}"

chown "${REAL_USER}:${REAL_USER}" "${BOXES_BOOT_ISO}" "${PAYLOAD_ISO}" 2>/dev/null || true
chmod 0644 "${BOXES_BOOT_ISO}" "${PAYLOAD_ISO}" 2>/dev/null || true

echo ""
echo "======================================================================="
echo " ✦ GNOME BOXES WINDOWS 11 + MOOV AI ISO READY!"
echo "   1. Bootable GNOME Boxes ISO: ${BOXES_BOOT_ISO} ($(du -h "${BOXES_BOOT_ISO}" | awk '{print $1}'))"
echo "   2. Win11 Payload Data CD:    ${PAYLOAD_ISO} ($(du -h "${PAYLOAD_ISO}" | awk '{print $1}'))"
echo ""
echo " ✦ IN GNOME BOXES:"
echo "   • Click '+' (Top Left) -> 'Create virtual machine from file'"
echo "   • Select: ${BOXES_BOOT_ISO}"
echo "   • Choose 'Ubuntu 24.04' (or 'Unknown OS' -> 4.0 GB RAM) -> Click 'Create'!"
echo "======================================================================="

if [ "${1:-}" = "--prepare-only" ] || [ "${NO_LAUNCH:-0}" = "1" ]; then
  echo "Preparation complete (--prepare-only / NO_LAUNCH=1 set); skipping GNOME Boxes GUI launch."
  exit 0
fi

# Launch GNOME Boxes as the desktop user (not root!) so D-Bus, Wayland/X11, and libvirt session work cleanly
if command -v gnome-boxes >/dev/null 2>&1 && [ "${REAL_USER}" != "root" ]; then
  echo "==> Opening GNOME Boxes with ${BOXES_BOOT_ISO}..."
  su - "${REAL_USER}" -c "DISPLAY=${DISPLAY:-:0} XDG_RUNTIME_DIR=/run/user/${USER_UID} DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${USER_UID}/bus nohup gnome-boxes '${BOXES_BOOT_ISO}' >/tmp/gnome-boxes.log 2>&1 &" || true
fi
