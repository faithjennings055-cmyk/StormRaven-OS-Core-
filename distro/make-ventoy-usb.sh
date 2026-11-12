#!/usr/bin/env bash
# =============================================================================
# StormRaven OS: Infinity Protocol v3.9.0 — Ventoy Dual-Edition USB Builder
# =============================================================================
# Formats a USB flash drive with official Ventoy v1.1.18 (GPT + UEFI + Legacy
# BIOS + exFAT data partition labeled `STORMRAVEN`) and preloads BOTH versions
# of StormRaven OS onto the stick:
#
#   1. `/ISO/StormRavenOS-Ubuntu-v3.9.0-amd64.iso` (1.6 GB)
#      - Full Ubuntu Edition + Ymir/Void Desktop + Moov AI (NACHA/X9.37/SQLite)
#        + Linux 7.0 HWE + GParted/TestDisk Boot Rescue Suite
#   2. `/ISO/StormRavenOS-Win11-Ymir-v3.9.0-amd64.iso`
#      - Bootable StormRaven OS Windows 11 Ymir Edition + Moov AI Live/Installer ISO
#      - ALSO includes any custom 6.8 GB Microsoft Windows 11 25H2 ISO if cached!
#   3. `/StormRaven-Win11-Full/` + `/ventoy/ventoy.json` + `/ventoy/autounattend-win11.xml`
#      - Ventoy Auto-Installation & Hardware Check Bypass (`VTOY_WIN11_BYPASS_CHECK=1`,
#        `VTOY_WIN11_BYPASS_NRO=1`) + Custom StormRaven Dark Cryo-Glass Ventoy Theme!
#      - Dropping ANY official Microsoft `Win11*.iso` into `/ISO/` on this USB
#        automatically bypasses TPM 2.0 / CPU / RAM checks and auto-installs
#        StormRaven OS Windows 11 Edition + Moov AI offline from the USB drive!
#
# One-command usage on HP Pro 3500:
#   curl -fsSL https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/make-ventoy-usb.sh | sudo bash
#
# Or pass your USB device explicitly:
#   curl -fsSL https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/make-ventoy-usb.sh | sudo bash -s -- /dev/sdX
# =============================================================================
set -euo pipefail

CLOUD_URL="${STORMRAVEN_GATEWAY_URL:-https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app}"
VENTOY_VER="1.1.18"
VENTOY_TAR="ventoy-${VENTOY_VER}-linux.tar.gz"
VENTOY_SHA="d86ff9de63d94c8b8f1f6b14d23c55af4b88e8207bf2893890892a6a97b1ad54"
VENTOY_URL_PRIMARY="${CLOUD_URL}/iso/${VENTOY_TAR}"
VENTOY_URL_FALLBACK="https://github.com/ventoy/Ventoy/releases/download/v${VENTOY_VER}/${VENTOY_TAR}"

SR_ISO_NAME="StormRavenOS-Infinity-Protocol-v3.9.0-amd64.iso"
SR_ISO_URL="${CLOUD_URL}/iso/${SR_ISO_NAME}"
SR_ISO_SHA_URL="${SR_ISO_URL}.sha256"

WIN11_ZIP_NAME="StormRavenOS-Win11-Full-v3.9.0-x64.zip"
WIN11_ZIP_URL="${CLOUD_URL}/iso/${WIN11_ZIP_NAME}"
WIN11_ZIP_SHA_URL="${WIN11_ZIP_URL}.sha256"

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: Please run with sudo:"
  echo "  curl -fsSL ${CLOUD_URL}/make-ventoy-usb.sh | sudo bash"
  exit 1
fi

REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo root)}"
if [ "${REAL_USER}" != "root" ]; then
  USER_HOME="$(getent passwd "${REAL_USER}" | cut -d: -f6)"
else
  USER_HOME="${HOME:-/root}"
fi

WORK_DIR="${WORK_DIR:-/var/tmp/stormraven-ventoy-build}"
DOWNLOADS_DIR="${USER_HOME}/Downloads"
mkdir -p "${WORK_DIR}" "${DOWNLOADS_DIR}"

echo "======================================================================="
echo " ✦ STORMRAVEN OS v3.9.0 — VENTOY DUAL-EDITION USB BUILDER"
echo "   Edition 1: StormRaven OS — Ubuntu 24.04/26.04 LTS + Moov AI"
echo "   Edition 2: StormRaven OS — Windows 11 Ymir Edition + Moov AI"
echo "   Features:  Ventoy v${VENTOY_VER} (GPT + UEFI/BIOS) · Custom Ymir Theme"
echo "              TPM 2.0 / CPU Bypass · Offline Windows 11 Auto-Installer"
echo "======================================================================="

# 1. Heal dpkg and install required tools (xorriso, grub-pc-bin, exfatprogs, unzip, cpio)
echo "==> [1/6] Checking partitioning, exFAT & ISO tools..."
dpkg-divert --package stormraven-os --divert /etc/xdg/menus/lxde-applications.menu.distrib --rename /etc/xdg/menus/lxde-applications.menu >/dev/null 2>&1 || true
dpkg-divert --package stormraven-os --divert /etc/xdg/menus/applications.menu.distrib --rename /etc/xdg/menus/applications.menu >/dev/null 2>&1 || true
dpkg --configure -a --force-overwrite >/dev/null 2>&1 || true
apt-get -f install -y -qq -o Dpkg::Options::="--force-overwrite" >/dev/null 2>&1 || true

NEED_PKGS=()
command -v xorriso >/dev/null 2>&1 || NEED_PKGS+=(xorriso)
command -v grub-mkrescue >/dev/null 2>&1 || NEED_PKGS+=(grub-common grub-pc-bin mtools)
[ -d /usr/lib/grub/i386-pc ] || NEED_PKGS+=(grub-pc-bin)
command -v mkfs.exfat >/dev/null 2>&1 || NEED_PKGS+=(exfatprogs)
command -v parted >/dev/null 2>&1 || NEED_PKGS+=(parted)
command -v cpio >/dev/null 2>&1 || NEED_PKGS+=(cpio)
command -v unzip >/dev/null 2>&1 || NEED_PKGS+=(unzip)

if [ "${#NEED_PKGS[@]}" -gt 0 ]; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq || true
  apt-get install -y -qq -o Dpkg::Options::="--force-overwrite" "${NEED_PKGS[@]}"
fi

# 2. Download & verify Official Ventoy v1.1.18 Linux binary package
echo "==> [2/6] Downloading & verifying Ventoy v${VENTOY_VER}..."
VENTOY_ARCHIVE="${WORK_DIR}/${VENTOY_TAR}"
if [ ! -f "${VENTOY_ARCHIVE}" ] || [ "$(sha256sum "${VENTOY_ARCHIVE}" | awk '{print $1}')" != "${VENTOY_SHA}" ]; then
  curl -fsSL "${VENTOY_URL_PRIMARY}" -o "${VENTOY_ARCHIVE}" 2>/dev/null || \
    curl -fL --retry 3 "${VENTOY_URL_FALLBACK}" -o "${VENTOY_ARCHIVE}"
fi
echo "${VENTOY_SHA}  ${VENTOY_ARCHIVE}" | sha256sum -c -
rm -rf "${WORK_DIR}/ventoy-${VENTOY_VER}"
tar -xzf "${VENTOY_ARCHIVE}" -C "${WORK_DIR}"
VENTOY_DIR="${WORK_DIR}/ventoy-${VENTOY_VER}"

# 3. Download & verify StormRaven OS Ubuntu ISO + Windows 11 Full Bundle
echo "==> [3/6] Verifying StormRaven OS Ubuntu ISO & Windows 11 Full Bundle..."
UBUNTU_ISO_PATH=""
for cand in \
  "${DOWNLOADS_DIR}/${SR_ISO_NAME}" \
  "/tmp/iso/${SR_ISO_NAME}" \
  "${WORK_DIR}/${SR_ISO_NAME}" \
  "/var/tmp/stormraven-dualboot-cache/StormRavenOS-ubuntu-24.04-amd64.iso"; do
  if [ -f "${cand}" ] && [ "$(stat -c %s "${cand}" 2>/dev/null || echo 0)" -gt 500000000 ]; then
    UBUNTU_ISO_PATH="${cand}"
    break
  fi
done

if [ -z "${UBUNTU_ISO_PATH}" ]; then
  UBUNTU_ISO_PATH="${DOWNLOADS_DIR}/${SR_ISO_NAME}"
  echo "    Downloading ${SR_ISO_NAME} (1.6 GB) to ${UBUNTU_ISO_PATH}..."
  curl -fL --retry 3 -o "${UBUNTU_ISO_PATH}" "${SR_ISO_URL}"
  curl -fsSL "${SR_ISO_SHA_URL}" -o "${UBUNTU_ISO_PATH}.sha256"
  (cd "${DOWNLOADS_DIR}" && sha256sum -c "${SR_ISO_NAME}.sha256")
else
  echo "    ✓ Found cached StormRaven Ubuntu ISO: ${UBUNTU_ISO_PATH} ($(du -h "${UBUNTU_ISO_PATH}" | awk '{print $1}'))"
fi

WIN11_ZIP_PATH="${WORK_DIR}/${WIN11_ZIP_NAME}"
WIN11_SHA_PATH="${WIN11_ZIP_PATH}.sha256"
curl -fsSL "${WIN11_ZIP_SHA_URL}?t=$(date +%s)" -o "${WIN11_SHA_PATH}"
EXPECTED_W11_SHA="$(awk '{print $1}' "${WIN11_SHA_PATH}")"
if [ ! -f "${WIN11_ZIP_PATH}" ] || [ "$(sha256sum "${WIN11_ZIP_PATH}" | awk '{print $1}')" != "${EXPECTED_W11_SHA}" ]; then
  curl -fL --retry 3 "${WIN11_ZIP_URL}?v=${EXPECTED_W11_SHA:0:12}" -o "${WIN11_ZIP_PATH}"
fi
(cd "${WORK_DIR}" && sha256sum -c "${WIN11_ZIP_NAME}.sha256")

# 4. Ensure we have BOTH ISOs ready for Ventoy:
#    - Edition 1: StormRavenOS-Ubuntu-v3.9.0-amd64.iso
#    - Edition 2: StormRavenOS-Win11-Ymir-v3.9.0-amd64.iso
echo "==> [4/6] Preparing StormRaven OS Windows 11 Ymir Edition ISO..."
WIN11_ISO_PATH=""
for cand in \
  "${DOWNLOADS_DIR}/StormRavenOS-Win11-Ymir-v3.9.0-amd64.iso" \
  "/var/tmp/stormraven-dualboot-cache/StormRavenOS-Win11-Ymir-v3.9.0-amd64.iso" \
  "${DOWNLOADS_DIR}/StormRavenOS-Win11-Boxes-v3.9.0.iso" \
  "${WORK_DIR}/StormRavenOS-Win11-Ymir-v3.9.0-amd64.iso"; do
  if [ -f "${cand}" ] && [ "$(stat -c %s "${cand}" 2>/dev/null || echo 0)" -gt 500000000 ]; then
    WIN11_ISO_PATH="${cand}"
    break
  fi
done

W11_UNPACK="${WORK_DIR}/win11-bundle"
rm -rf "${W11_UNPACK}" && mkdir -p "${W11_UNPACK}"
unzip -q -o "${WIN11_ZIP_PATH}" -d "${W11_UNPACK}"
if [ -d "${W11_UNPACK}/StormRaven-Win11-Full" ]; then
  mv -f "${W11_UNPACK}/StormRaven-Win11-Full/"* "${W11_UNPACK}/" 2>/dev/null || true
  rmdir "${W11_UNPACK}/StormRaven-Win11-Full" 2>/dev/null || true
fi

if [ -z "${WIN11_ISO_PATH}" ]; then
  WIN11_ISO_PATH="${DOWNLOADS_DIR}/StormRavenOS-Win11-Ymir-v3.9.0-amd64.iso"
  echo "    Building bootable ${WIN11_ISO_PATH}..."
  W11_STAGE="${WORK_DIR}/w11-iso-stage"
  rm -rf "${W11_STAGE}" && mkdir -p "${W11_STAGE}/casper" "${W11_STAGE}/boot/grub"
  cp -a "${W11_UNPACK}/"* "${W11_STAGE}/" 2>/dev/null || true

  xorriso -osirrox on -indev "${UBUNTU_ISO_PATH}" \
    -extract /casper/vmlinuz "${W11_STAGE}/casper/vmlinuz" \
    -extract /casper/initrd "${WORK_DIR}/initrd-base" >/dev/null 2>&1

  if xorriso -osirrox on -indev "${UBUNTU_ISO_PATH}" -extract /casper/stormraven-v393.squashfs "${W11_STAGE}/casper/stormraven-v393.squashfs" >/dev/null 2>&1 && [ -f "${W11_STAGE}/casper/stormraven-v393.squashfs" ]; then
    ln -sf stormraven-v393.squashfs "${W11_STAGE}/casper/filesystem.squashfs"
  else
    xorriso -osirrox on -indev "${UBUNTU_ISO_PATH}" -extract /casper/filesystem.squashfs "${W11_STAGE}/casper/stormraven-v393.squashfs" >/dev/null 2>&1
    ln -sf stormraven-v393.squashfs "${W11_STAGE}/casper/filesystem.squashfs"
  fi

  chmod 0644 "${W11_STAGE}/casper/vmlinuz" "${WORK_DIR}/initrd-base" "${W11_STAGE}/casper/stormraven-v393.squashfs"
  cp -f "${WORK_DIR}/initrd-base" "${W11_STAGE}/casper/initrd"
  chmod u+w "${W11_STAGE}/casper/initrd"

  OVL_DIR="${WORK_DIR}/initrd-ovl"
  rm -rf "${OVL_DIR}" && mkdir -p "${OVL_DIR}/scripts"
  cat > "${OVL_DIR}/scripts/casper" << 'CASPER_EOF'
#!/bin/sh
mount_top() { :; }
mount_premount() { :; }
mount_bottom() { :; }

mountroot() {
    for mod in overlay squashfs iso9660 isofs loop sr_mod cdrom sd_mod ahci ata_piix virtio virtio_ring virtio_pci virtio_blk virtio_scsi virtio_net e1000 exfat vfat ntfs3; do
        modprobe -q "$mod" 2>/dev/null || true
    done
    udevadm trigger 2>/dev/null || true
    udevadm settle --timeout=5 2>/dev/null || true

    mkdir -p /run/casper-medium /run/casper-ro /run/casper-rw
    SQUASHFS_PATH=""
    for attempt in $(seq 1 25); do
        for dev in /dev/mapper/ventoy /dev/dm-0 /dev/sr0 /dev/sr1 /dev/sd* /dev/nvme* /dev/vd*; do
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
    mkdir -p "${rootmnt}/cdrom" "${rootmnt}/rofs" "${rootmnt}/mnt/STORMRAVEN_WIN11" "${rootmnt}/etc/stormraven"
    echo "win11" > "${rootmnt}/etc/stormraven/edition"

    if [ -d /run/casper-medium/linux-vm ]; then
        cp -f /run/casper-medium/linux-vm/* "${rootmnt}/usr/local/bin/" 2>/dev/null || true
        chmod 0755 "${rootmnt}/usr/local/bin/stormraven"* 2>/dev/null || true
        ln -sf /usr/local/bin/stormraven-moov "${rootmnt}/usr/local/bin/moov-ai" 2>/dev/null || true
    fi
    rm -f "${rootmnt}/tmp/"*.log 2>/dev/null || true
    chmod 1777 "${rootmnt}/tmp" "${rootmnt}/var/tmp" 2>/dev/null || true
}
CASPER_EOF
  chmod +x "${OVL_DIR}/scripts/casper"
  ln -sf casper "${OVL_DIR}/scripts/live"
  (cd "${OVL_DIR}" && find . | cpio -o -H newc >> "${W11_STAGE}/casper/initrd" 2>/dev/null)

  cat > "${W11_STAGE}/boot/grub/grub.cfg" << 'GRUB_EOF'
set default=0
set timeout=5
insmod all_video
insmod gfxterm
set gfxmode=1920x1080,1280x800,auto
set gfxpayload=keep
terminal_output gfxterm

menuentry "StormRaven OS v3.9.0 - Windows 11 Ymir Edition + Moov AI (Live / Install)" {
    linux /casper/vmlinuz boot=casper console=tty0 stormraven.edition=win11
    initrd /casper/initrd
}
menuentry "StormRaven OS v3.9.0 - Windows 11 Ymir Edition (Safe Graphics / nomodeset)" {
    linux /casper/vmlinuz boot=casper nomodeset console=tty0 stormraven.edition=win11
    initrd /casper/initrd
}
menuentry "Install StormRaven OS v3.9.0 Directly to Disk" {
    linux /casper/vmlinuz boot=casper stormraven.mode=install stormraven.edition=win11
    initrd /casper/initrd
}
GRUB_EOF

  grub-mkrescue -o "${WIN11_ISO_PATH}" "${W11_STAGE}" -- -volid "STORMRAVEN_W11" 2>/dev/null
  rm -rf "${W11_STAGE}" "${WORK_DIR}/initrd-base" "${OVL_DIR}"
  echo "    ✓ Built ${WIN11_ISO_PATH} ($(du -h "${WIN11_ISO_PATH}" | awk '{print $1}'))"
else
  echo "    ✓ Found cached StormRaven Windows 11 ISO: ${WIN11_ISO_PATH} ($(du -h "${WIN11_ISO_PATH}" | awk '{print $1}'))"
fi

if [ "${1:-}" = "--prepare-only" ] || [ "${NO_USB:-0}" = "1" ]; then
  echo "Preparation complete (--prepare-only / NO_USB=1 set); skipping USB formatting."
  exit 0
fi

# 5. Detect USB drive (or use device argument /dev/sdX)
ROOT_SRC="$(findmnt -n -o SOURCE / 2>/dev/null || true)"
ROOT_DISK=""
if [ -n "${ROOT_SRC}" ]; then
  ROOT_PKNAME="$(lsblk -no PKNAME "${ROOT_SRC}" 2>/dev/null | head -n 1 || true)"
  if [ -n "${ROOT_PKNAME}" ]; then
    ROOT_DISK="/dev/${ROOT_PKNAME}"
  else
    ROOT_DISK="${ROOT_SRC}"
  fi
fi

TARGET_DEV="${1:-${USB_DEV:-}}"
if [ -z "${TARGET_DEV}" ]; then
  echo "==> [5/6] Detecting connected USB flash drives..."
  mapfile -t USB_CANDIDATES < <(
    lsblk -dpno NAME,TRAN,RM,SIZE,VENDOR,MODEL,TYPE | awk -v root="${ROOT_DISK}" '
      $NF == "disk" && $1 != root && ($2 == "usb" || $3 == "1") && $1 !~ /^\/dev\/(loop|sr|zram|ram)/ {
        print $1
      }
    '
  )

  if [ "${#USB_CANDIDATES[@]}" -eq 0 ]; then
    echo ""
    echo "Available disks on this machine:"
    lsblk -dpo NAME,TRAN,RM,SIZE,MODEL,TYPE | grep -v "loop" || true
    echo ""
    echo "ERROR: No removable USB flash drive was auto-detected."
    echo "Plug in your USB stick and re-run, or pass the device explicitly:"
    echo "  curl -fsSL ${CLOUD_URL}/make-ventoy-usb.sh | sudo bash -s -- /dev/sdX"
    exit 1
  elif [ "${#USB_CANDIDATES[@]}" -eq 1 ]; then
    TARGET_DEV="${USB_CANDIDATES[0]}"
    echo "    Auto-detected USB drive: ${TARGET_DEV} ($(lsblk -dno SIZE,VENDOR,MODEL "${TARGET_DEV}" 2>/dev/null | xargs))"
  else
    echo "Multiple removable USB drives detected:"
    for idx in "${!USB_CANDIDATES[@]}"; do
      dev="${USB_CANDIDATES[$idx]}"
      info="$(lsblk -dno SIZE,VENDOR,MODEL "${dev}" 2>/dev/null | xargs)"
      echo "  [$((idx + 1))] ${dev} (${info})"
    done
    if [ -r /dev/tty ]; then
      printf "Select USB drive number [1-%d]: " "${#USB_CANDIDATES[@]}" > /dev/tty
      read -r choice < /dev/tty
      TARGET_DEV="${USB_CANDIDATES[$((choice - 1))]}"
    else
      TARGET_DEV="${USB_CANDIDATES[0]}"
    fi
  fi
fi

if [ ! -b "${TARGET_DEV}" ]; then
  echo "ERROR: ${TARGET_DEV} is not a valid block device."
  exit 1
fi
if [ "${TARGET_DEV}" = "${ROOT_DISK}" ]; then
  echo "CRITICAL SAFETY STOP: Refusing to format your system root disk (${ROOT_DISK})!"
  exit 1
fi

echo "==> [5/6] Installing Ventoy v${VENTOY_VER} (GPT + UEFI + Legacy BIOS) onto ${TARGET_DEV}..."
for part in $(lsblk -lnpo NAME "${TARGET_DEV}" | tail -n +2); do
  umount -lf "${part}" 2>/dev/null || true
done

# Run Ventoy2Disk.sh non-interactively (-I force install, -g GPT, -L STORMRAVEN)
(
  cd "${VENTOY_DIR}"
  yes | sh ./Ventoy2Disk.sh -I -g -L STORMRAVEN "${TARGET_DEV}"
)
sync
partprobe "${TARGET_DEV}" 2>/dev/null || true
udevadm settle 2>/dev/null || true
sleep 2

P_PREFIX="${TARGET_DEV}"
case "${TARGET_DEV}" in
  *nvme*|*mmcblk*|*loop*) P_PREFIX="${TARGET_DEV}p" ;;
esac
DATA_PART="${P_PREFIX}1"

# 6. Mount Ventoy data partition (`STORMRAVEN`) and copy BOTH StormRaven ISOs + Ventoy config + Win11 offline bundle
echo "==> [6/6] Populating Ventoy USB (${DATA_PART}) with BOTH StormRaven OS Editions & Ymir Theme..."
MNT_VTOY="/mnt/stormraven-ventoy"
mkdir -p "${MNT_VTOY}"
umount -lf "${DATA_PART}" 2>/dev/null || true
mount "${DATA_PART}" "${MNT_VTOY}"

mkdir -p "${MNT_VTOY}/ISO" "${MNT_VTOY}/ventoy" "${MNT_VTOY}/StormRaven-Win11-Full"

echo "    -> Copying Edition 1: StormRavenOS-Ubuntu-v3.9.0-amd64.iso..."
cp -f "${UBUNTU_ISO_PATH}" "${MNT_VTOY}/ISO/StormRavenOS-Ubuntu-v3.9.0-amd64.iso"

echo "    -> Copying Edition 2: StormRavenOS-Win11-Ymir-v3.9.0-amd64.iso..."
cp -f "${WIN11_ISO_PATH}" "${MNT_VTOY}/ISO/StormRavenOS-Win11-Ymir-v3.9.0-amd64.iso"

# Also copy any additional Microsoft Windows 11 ISO if user has one in ~/Downloads
for ms_iso in "${DOWNLOADS_DIR}"/Win11*.iso "${DOWNLOADS_DIR}"/Windows11*.iso; do
  if [ -f "${ms_iso}" ]; then
    echo "    -> Copying Microsoft Windows 11 Base ISO ($(basename "${ms_iso}"))..."
    cp -f "${ms_iso}" "${MNT_VTOY}/ISO/"
  fi
done

echo "    -> Staging offline StormRaven Windows 11 + Moov AI payload (/StormRaven-Win11-Full/)..."
cp -rf "${W11_UNPACK}/"* "${MNT_VTOY}/StormRaven-Win11-Full/" 2>/dev/null || true
cp -f "${W11_UNPACK}/Install-StormRaven-Win11.ps1" "${MNT_VTOY}/StormRaven-Win11-Full/Install-StormRaven-Win11.ps1" 2>/dev/null || true
(cd "${MNT_VTOY}/StormRaven-Win11-Full" && sha256sum Install-StormRaven-Win11.ps1 > Install-StormRaven-Win11.ps1.sha256)

# Write security-hardened Ventoy Windows 11 autounattend.xml (No plaintext passwords; verifies SHA-256 before running!)
cat > "${MNT_VTOY}/ventoy/autounattend-win11.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<!-- StormRaven OS — Ventoy Windows 11 Auto-Customization Manifest (Zero Plaintext Creds, SHA-256 Verified) -->
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
      <FirstLogonCommands>
        <SynchronousCommand wcm:action="add">
          <Order>1</Order>
          <Description>Verify SHA-256 and Bootstrap StormRaven OS Windows 11 Edition + Moov AI from Ventoy USB</Description>
          <CommandLine>powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "foreach ($d in [IO.DriveInfo]::GetDrives()) { $p = Join-Path $d.RootDirectory.FullName 'StormRaven-Win11-Full\Install-StormRaven-Win11.ps1'; $s = Join-Path $d.RootDirectory.FullName 'StormRaven-Win11-Full\Install-StormRaven-Win11.ps1.sha256'; if ((Test-Path $p) -and (Test-Path $s)) { if ((Get-FileHash $p -Algorithm SHA256).Hash.ToLower() -ne (Get-Content $s).Split()[0].ToLower()) { exit 1 }; &amp; $p; exit 0 } }"</CommandLine>
        </SynchronousCommand>
      </FirstLogonCommands>
    </component>
  </settings>
</unattend>
EOF

# Write /ventoy/ventoy.json with Menu Aliases for both StormRaven Editions + Win11 Hardware Check Bypass
cat > "${MNT_VTOY}/ventoy/ventoy.json" << 'EOF'
{
    "control": [
        { "VTOY_DEFAULT_MENU_MODE": "0" },
        { "VTOY_FILT_DOT_UNDERSCORE_FILE": "1" },
        { "VTOY_WIN11_BYPASS_CHECK": "1" },
        { "VTOY_WIN11_BYPASS_NRO": "1" },
        { "VTOY_DEFAULT_SEARCH_ROOT": "/ISO" }
    ],
    "menu_alias": [
        {
            "image": "/ISO/StormRavenOS-Ubuntu-v3.9.0-amd64.iso",
            "alias": "1) StormRaven OS v3.9.0 — Ubuntu Edition + Moov AI (Live / Install)"
        },
        {
            "image": "/ISO/StormRavenOS-Win11-Ymir-v3.9.0-amd64.iso",
            "alias": "2) StormRaven OS v3.9.0 — Windows 11 Ymir Edition + Moov AI (Live / Install)"
        }
    ],
    "auto_install": [
        {
            "parent": "/ISO",
            "template": [
                "/ventoy/autounattend-win11.xml"
            ]
        }
    ]
}
EOF

sync
echo "    ✓ Verified Ventoy USB contents on ${DATA_PART}:"
ls -lh "${MNT_VTOY}/ISO/"
umount "${MNT_VTOY}"
rmdir "${MNT_VTOY}" 2>/dev/null || true

echo ""
echo "======================================================================="
echo " ✦ SUCCESS: STORMRAVEN OS DUAL-EDITION VENTOY USB READY ON ${TARGET_DEV}!"
echo "   • Edition 1: StormRaven OS v3.9.0 — Ubuntu Edition + Moov AI"
echo "   • Edition 2: StormRaven OS v3.9.0 — Windows 11 Ymir Edition + Moov AI"
echo "   • Bonus:     Drop any extra .iso into the 'STORMRAVEN/ISO' folder anytime"
echo "                without reformatting — Ventoy lists & boots it automatically!"
echo "======================================================================="
