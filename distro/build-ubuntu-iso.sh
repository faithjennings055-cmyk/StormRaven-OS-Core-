#!/usr/bin/env bash
# =============================================================================
# StormRaven OS 24.04 LTS (Ubuntu Noble Numbat) — Reproducible Live ISO Builder
# =============================================================================
# Builds a bootable Ubuntu 24.04 LTS (noble) hybrid BIOS/UEFI Live ISO with:
#   - Ubuntu 24.04 LTS (noble) userspace & kernel from archive.ubuntu.com
#   - StormRaven.Kernel + Bifrost HTTP/WS Gateway auto-starting on :8787
#   - StormRaven Python Pantheon modules (/opt/stormraven/python/)
#   - StormRaven Companion PWA (/opt/stormraven/webapp/)
#   - /usr/local/bin/stormraven CLI helper
#   - systemd-networkd DHCP networking + serial & tty1 live login
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORK_DIR="${WORK_DIR:-/tmp/stormraven-ubuntu-build}"
CHROOT_DIR="${WORK_DIR}/chroot"
ISO_STAGING="${WORK_DIR}/iso"
OUTPUT_ISO="${OUTPUT_ISO:-${REPO_ROOT}/StormRavenOS-ubuntu-24.04-amd64.iso}"
UBUNTU_SUITE="noble"
UBUNTU_MIRROR="${UBUNTU_MIRROR:-http://archive.ubuntu.com/ubuntu/}"
UBUNTU_SECURITY_MIRROR="${UBUNTU_SECURITY_MIRROR:-http://security.ubuntu.com/ubuntu/}"
KERNEL_PKG="${KERNEL_PKG:-linux-image-virtual}"
CLEAN_BUILD="${CLEAN_BUILD:-0}"

echo "==> [1/7] Checking host build dependencies..."
if [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
else
  SUDO=""
fi

export DEBIAN_FRONTEND=noninteractive
if ! command -v debootstrap >/dev/null 2>&1 || \
   ! command -v mksquashfs >/dev/null 2>&1 || \
   ! command -v xorriso >/dev/null 2>&1 || \
   ! command -v grub-mkrescue >/dev/null 2>&1; then
  $SUDO apt-get update -qq
  $SUDO apt-get install -y -qq \
    debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin \
    mtools dosfstools ca-certificates curl
fi

# Ensure debootstrap knows about Ubuntu noble
if [ ! -e /usr/share/debootstrap/scripts/noble ]; then
  $SUDO ln -sf gutsy /usr/share/debootstrap/scripts/noble
fi

cleanup_mounts() {
  for mp in dev/pts dev proc sys run; do
    if mountpoint -q "${CHROOT_DIR}/${mp}" 2>/dev/null; then
      $SUDO umount -lf "${CHROOT_DIR}/${mp}" 2>/dev/null || true
    fi
  done
}
trap cleanup_mounts EXIT

cleanup_mounts
if [ "${CLEAN_BUILD}" = "1" ] || [ ! -x "${CHROOT_DIR}/bin/bash" ]; then
  echo "==> [2/7] Bootstrapping Ubuntu 24.04 LTS (${UBUNTU_SUITE}) rootfs into ${CHROOT_DIR}..."
  $SUDO rm -rf "${WORK_DIR}"
  mkdir -p "${CHROOT_DIR}" "${ISO_STAGING}/casper" "${ISO_STAGING}/live" "${ISO_STAGING}/boot/grub"

  $SUDO debootstrap \
    --arch=amd64 \
    --variant=minbase \
    --components=main,restricted,universe,multiverse \
    "${UBUNTU_SUITE}" \
    "${CHROOT_DIR}" \
    "${UBUNTU_MIRROR}"
else
  echo "==> [2/7] Reusing existing Ubuntu 24.04 LTS (${UBUNTU_SUITE}) rootfs in ${CHROOT_DIR}..."
  $SUDO rm -rf "${ISO_STAGING}"
  mkdir -p "${ISO_STAGING}/casper" "${ISO_STAGING}/live" "${ISO_STAGING}/boot/grub"
fi

echo "==> [3/7] Configuring Ubuntu 24.04 APT sources & bind mounts..."
$SUDO tee "${CHROOT_DIR}/etc/apt/sources.list" >/dev/null <<EOF
deb ${UBUNTU_MIRROR} ${UBUNTU_SUITE} main restricted universe multiverse
deb ${UBUNTU_MIRROR} ${UBUNTU_SUITE}-updates main restricted universe multiverse
deb ${UBUNTU_SECURITY_MIRROR} ${UBUNTU_SUITE}-security main restricted universe multiverse
EOF

$SUDO mount --bind /dev "${CHROOT_DIR}/dev"
$SUDO mount -t devpts devpts "${CHROOT_DIR}/dev/pts"
$SUDO mount -t proc proc "${CHROOT_DIR}/proc"
$SUDO mount -t sysfs sysfs "${CHROOT_DIR}/sys"
$SUDO rm -f "${CHROOT_DIR}/etc/resolv.conf"
$SUDO cp -L /etc/resolv.conf "${CHROOT_DIR}/etc/resolv.conf"

# Prevent daemons from starting inside chroot during package installation
$SUDO tee "${CHROOT_DIR}/usr/sbin/policy-rc.d" >/dev/null <<'EOF'
#!/bin/sh
exit 101
EOF
$SUDO chmod +x "${CHROOT_DIR}/usr/sbin/policy-rc.d"

echo "==> [4/7] Installing Ubuntu 24.04 LTS kernel, systemd, casper, Python & runtime packages..."
$SUDO chroot "${CHROOT_DIR}" /bin/bash -e <<EOF
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y --no-install-recommends \
  ${KERNEL_PKG} \
  initramfs-tools \
  zstd \
  casper \
  systemd \
  systemd-sysv \
  systemd-resolved \
  dbus \
  udev \
  kmod \
  sudo \
  login \
  passwd \
  util-linux \
  procps \
  iproute2 \
  iputils-ping \
  net-tools \
  curl \
  wget \
  ca-certificates \
  sqlite3 \
  libsqlite3-0 \
  python3 \
  python-is-python3 \
  python3-rich \
  python3-psutil \
  locales \
  libicu74 \
  libssl3t64 \
  less \
  nano
locale-gen en_US.UTF-8 || true
EOF

echo "==> [4.5/7] Installing modern systems layer (VPN, VM, forensics, baseline)..."
$SUDO chroot "${CHROOT_DIR}" /bin/bash -e <<EOF
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

# --- Built-in VPN (WireGuard native + firewall) ---
apt-get install -y --no-install-recommends \
  wireguard \
  wireguard-tools \
  ufw

# --- Built-in VM capabilities (KVM/QEMU + libvirt + virt-manager) ---
apt-get install -y --no-install-recommends \
  qemu-system-x86 \
  qemu-utils \
  libvirt-daemon-system \
  libvirt-clients \
  virt-manager \
  ovmf

# --- Built-in forensic subsystems ---
apt-get install -y --no-install-recommends \
  sleuthkit \
  binwalk \
  foremost \
  testdisk \
  yara \
  hashdeep \
  dc3dd \
  ewf-tools \
  chkrootkit \
  libimage-exiftool-perl

# --- Modern desktop baseline (network, audio, printing, scanning, media, tools) ---
apt-get install -y --no-install-recommends \
  network-manager \
  bluez \
  pipewire \
  pipewire-audio \
  wireplumber \
  cups \
  cups-client \
  sane-utils \
  ffmpeg \
  p7zip-full \
  unzip \
  zip \
  rsync \
  gnupg \
  openssh-client \
  openssh-server \
  unattended-upgrades \
  timeshift \
  libnss-systemd

apt-get clean
EOF

# Build StormRaven.Kernel from source instead of using pre-compiled binary
echo "==> [5.1/7] Building StormRaven.Kernel from source..."
(
    cd "${REPO_ROOT}"
    # Use dotnet-install script for ephemeral build environments if dotnet is missing
    if ! command -v dotnet >/dev/null 2>&1; then
        curl -fsSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin --channel 8.0 --install-dir "${WORK_DIR}/dotnet"
        export PATH="${WORK_DIR}/dotnet:${PATH}"
    fi
    dotnet publish StormRaven.Kernel.csproj -c Release -r linux-x64 --self-contained true -o "${CHROOT_DIR}/opt/stormraven/" /p:PublishSingleFile=true /p:PublishTrimmed=true
)

echo "==> [5.2/7] Installing StormRaven OS payload, services, CLI, and Ubuntu 24.04 branding..."

# Build the Next.js UI for static export
echo "Building Alfheim UI..."
if [ -d "${REPO_ROOT}/webapp" ]; then
    (cd "${REPO_ROOT}/webapp" && npm install && npm run build) || echo "UI build failed, using existing artifacts if available"
fi

# Copy includes.chroot tree (/etc, /opt/stormraven, /usr/local/bin/stormraven)
$SUDO cp -a "${SCRIPT_DIR}/live-build/config/includes.chroot/." "${CHROOT_DIR}/"

# Ensure latest Python Pantheon and Webapp files are in /opt/stormraven/
$SUDO mkdir -p "${CHROOT_DIR}/opt/stormraven/python" "${CHROOT_DIR}/opt/stormraven/webapp"
$SUDO cp -a "${REPO_ROOT}/StormRaven.Python/." "${CHROOT_DIR}/opt/stormraven/python/"

if [ -d "${REPO_ROOT}/webapp/out" ]; then
    $SUDO cp -a "${REPO_ROOT}/webapp/out/." "${CHROOT_DIR}/opt/stormraven/webapp/"
else
    $SUDO cp -a "${REPO_ROOT}/webapp/." "${CHROOT_DIR}/opt/stormraven/webapp/"
fi

# StormRaven.Kernel is built from source in step 5.1
$SUDO chmod +x "${CHROOT_DIR}/opt/stormraven/StormRaven.Kernel"
$SUDO chmod +x "${CHROOT_DIR}/usr/local/bin/stormraven"

# Install live initramfs hook & script so both boot=casper and boot=live mount the squashfs cleanly
$SUDO tee "${CHROOT_DIR}/etc/initramfs-tools/modules" >/dev/null <<'EOF'
overlay
squashfs
iso9660
loop
sr_mod
cdrom
sd_mod
ahci
ata_piix
virtio
virtio_ring
virtio_pci
virtio_blk
virtio_scsi
virtio_net
e1000
EOF

$SUDO tee "${CHROOT_DIR}/usr/share/initramfs-tools/hooks/stormraven-live" >/dev/null <<'EOF'
#!/bin/sh -e
PREREQS=""
case "$1" in
    prereqs) echo "$PREREQS"; exit 0 ;;
esac
. /usr/share/initramfs-tools/hook-functions
for mod in overlay squashfs iso9660 isofs loop sr_mod cdrom sd_mod ahci ata_piix virtio virtio_ring virtio_pci virtio_blk virtio_scsi virtio_net e1000; do
    manual_add_modules "$mod" 2>/dev/null || true
done
EOF
$SUDO chmod +x "${CHROOT_DIR}/usr/share/initramfs-tools/hooks/stormraven-live"

$SUDO tee "${CHROOT_DIR}/usr/share/initramfs-tools/scripts/casper" >/dev/null <<'EOF'
#!/bin/sh
# StormRaven OS Ubuntu 24.04 Live Rootfs Mounter (supports boot=casper and boot=live)

mount_top() { :; }
mount_premount() { :; }
mount_bottom() { :; }

mountroot() {
    echo "[StormRaven Live] Probing storage modules and searching for StormRaven Live medium..."
    for mod in overlay squashfs iso9660 isofs loop sr_mod cdrom sd_mod ahci ata_piix virtio virtio_ring virtio_pci virtio_blk virtio_scsi virtio_net e1000; do
        modprobe -q "$mod" 2>/dev/null || true
    done

    udevadm trigger 2>/dev/null || true
    udevadm settle --timeout=5 2>/dev/null || true

    mkdir -p /run/casper-medium /run/casper-ro /run/casper-rw
    SQUASHFS_PATH=""

    for attempt in $(seq 1 30); do
        for dev in /dev/sr0 /dev/sr1 /dev/vda /dev/vda1 /dev/sda /dev/sda1 /dev/sdb /dev/sdb1 /dev/sr* /dev/vd* /dev/sd* /dev/nvme*; do
            [ -b "$dev" ] || continue
            if mount -r -t iso9660 "$dev" /run/casper-medium 2>/dev/null || mount -r "$dev" /run/casper-medium 2>/dev/null; then
                if [ -f /run/casper-medium/casper/filesystem.squashfs ]; then
                    SQUASHFS_PATH="/run/casper-medium/casper/filesystem.squashfs"
                    echo "[StormRaven Live] Found live image on $dev ($SQUASHFS_PATH)"
                    break 2
                elif [ -f /run/casper-medium/live/filesystem.squashfs ]; then
                    SQUASHFS_PATH="/run/casper-medium/live/filesystem.squashfs"
                    echo "[StormRaven Live] Found live image on $dev ($SQUASHFS_PATH)"
                    break 2
                fi
                umount /run/casper-medium 2>/dev/null || true
            fi
        done
        sleep 1
    done

    if [ -z "$SQUASHFS_PATH" ]; then
        panic "[StormRaven Live] ERROR: Unable to locate /casper/filesystem.squashfs on any block device!"
    fi

    mount -t squashfs -o loop,ro "$SQUASHFS_PATH" /run/casper-ro
    mount -t tmpfs -o mode=0755 tmpfs /run/casper-rw
    mkdir -p /run/casper-rw/upper /run/casper-rw/work
    mount -t overlay overlay -o "lowerdir=/run/casper-ro,upperdir=/run/casper-rw/upper,workdir=/run/casper-rw/work" "${rootmnt}"
    mkdir -p "${rootmnt}/cdrom" "${rootmnt}/rofs"
    echo "[StormRaven Live] Overlay rootfs mounted successfully."
}
EOF
$SUDO chmod +x "${CHROOT_DIR}/usr/share/initramfs-tools/scripts/casper"
$SUDO ln -sf casper "${CHROOT_DIR}/usr/share/initramfs-tools/scripts/live"

# Copy Plymouth theme and Ethereal Void wallpapers into chroot before chrooting
$SUDO mkdir -p "${CHROOT_DIR}/usr/share/plymouth/themes/stormraven-void"
$SUDO cp -a "${REPO_ROOT}/distro/plymouth-theme/stormraven-void/." "${CHROOT_DIR}/usr/share/plymouth/themes/stormraven-void/"
$SUDO mkdir -p "${CHROOT_DIR}/usr/share/backgrounds/stormraven"
$SUDO cp -a "${REPO_ROOT}/distro/wallpapers/." "${CHROOT_DIR}/usr/share/backgrounds/stormraven/"

# Configure users, services, autologin, branding, and rebuild initramfs inside chroot
$SUDO chroot "${CHROOT_DIR}" /bin/bash -e <<'EOF'
mkdir -p /var/lib/stormraven /etc/stormraven /mnt/dev_drive/.shadow_logs

# Users: Provisioned with random/locked passwords for live session
# stormraven:stormraven (pw: stormraven), user (pw: live) -> CHANGED TO LOCKED/RANDOM
id -u stormraven >/dev/null 2>&1 || useradd -m -s /bin/bash -G sudo stormraven
id -u stormraven >/dev/null 2>&1 && usermod -p "$(openssl passwd -6 "$(openssl rand -base64 12)")" stormraven || true
id -u ubuntu >/dev/null 2>&1 && usermod -p "$(openssl passwd -6 "$(openssl rand -base64 12)")" ubuntu || true
id -u root >/dev/null 2>&1 && usermod -p "$(openssl passwd -6 "$(openssl rand -base64 12)")" root || true
id -u user >/dev/null 2>&1 && usermod -p "$(openssl passwd -6 "$(openssl rand -base64 12)")" user || true

# Sudo: Require password for sensitive operations (removed NOPASSWD:ALL)
mkdir -p /etc/sudoers.d
cat > /etc/sudoers.d/90-stormraven-live <<'SUDO'
ubuntu ALL=(ALL) ALL
stormraven ALL=(ALL) ALL
user ALL=(ALL) ALL
SUDO
chmod 0440 /etc/sudoers.d/90-stormraven-live

chown -R stormraven:stormraven /var/lib/stormraven /opt/stormraven /etc/stormraven /mnt/dev_drive

# Disable casper-md5check and casper shutdown prompt services
rm -f /etc/systemd/system/multi-user.target.wants/casper-md5check.service \
      /etc/systemd/system/final.target.wants/casper.service || true

# Enable systemd services
mkdir -p /etc/systemd/system/multi-user.target.wants
ln -sf /etc/systemd/system/stormraven-kernel.service /etc/systemd/system/multi-user.target.wants/stormraven-kernel.service
ln -sf /lib/systemd/system/libvirtd.service /etc/systemd/system/multi-user.target.wants/libvirtd.service || true
ln -sf /lib/systemd/system/bluetooth.service /etc/systemd/system/multi-user.target.wants/bluetooth.service || true
ln -sf /lib/systemd/system/cups.service /etc/systemd/system/multi-user.target.wants/cups.service || true
ln -sf /lib/systemd/system/ufw.service /etc/systemd/system/multi-user.target.wants/ufw.service || true
ln -sf /lib/systemd/system/unattended-upgrades.service /etc/systemd/system/multi-user.target.wants/unattended-upgrades.service || true
ln -sf /lib/systemd/system/systemd-networkd.service /etc/systemd/system/multi-user.target.wants/systemd-networkd.service || true
ln -sf /lib/systemd/system/systemd-resolved.service /etc/systemd/system/multi-user.target.wants/systemd-resolved.service || true

# Configure autologin on tty1 and serial ttyS0 for live session
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/override.conf <<'GETTY1'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ubuntu --noclear %I $TERM
GETTY1

mkdir -p /etc/systemd/system/serial-getty@ttyS0.service.d /etc/systemd/system/getty.target.wants
cat > /etc/systemd/system/serial-getty@ttyS0.service.d/override.conf <<'GETTYS0'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin ubuntu --keep-baud 115200,57600,38400,9600 %I $TERM
GETTYS0
ln -sf /lib/systemd/system/serial-getty@.service /etc/systemd/system/getty.target.wants/serial-getty@ttyS0.service || true

# Hosts file
cat > /etc/hosts <<'HOSTS'
127.0.0.1   localhost
127.0.1.1   stormraven
::1         localhost ip6-localhost ip6-loopback
HOSTS

# Re-apply StormRaven OS 24.04 LTS (Ubuntu Noble) /usr/lib/os-release & /etc/os-release
rm -f /etc/os-release /usr/lib/os-release
cat > /usr/lib/os-release <<'OSREL'
PRETTY_NAME="StormRaven OS 24.04 LTS (Ubuntu Noble)"
NAME="StormRaven OS"
VERSION_ID="24.04"
VERSION="24.04 LTS (Noble Numbat)"
VERSION_CODENAME=noble
ID=stormraven
ID_LIKE="ubuntu debian"
HOME_URL="https://github.com/faithjennings055-cmyk/StormRaven-OS-Core-"
SUPPORT_URL="https://github.com/faithjennings055-cmyk/StormRaven-OS-Core-/issues"
BUG_REPORT_URL="https://github.com/faithjennings055-cmyk/StormRaven-OS-Core-/issues"
PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
UBUNTU_CODENAME=noble
LOGO=stormraven
OSREL
ln -sf ../usr/lib/os-release /etc/os-release

cat > /etc/lsb-release <<'LSBREL'
DISTRIB_ID=StormRaven
DISTRIB_RELEASE=24.04
DISTRIB_CODENAME=noble
DISTRIB_DESCRIPTION="StormRaven OS 24.04 LTS (Ubuntu Noble)"
LSBREL

# Install Plymouth and set the StormRaven Void theme inside chroot
export DEBIAN_FRONTEND=noninteractive
export PATH="$PATH:/usr/sbin"
apt-get install -y --no-install-recommends plymouth plymouth-themes
update-alternatives --set default.plymouth /usr/share/plymouth/themes/stormraven-void/stormraven-void.plymouth 2>/dev/null || ln -sf /usr/share/plymouth/themes/stormraven-void/stormraven-void.plymouth /usr/share/plymouth/themes/default.plymouth

# Update initramfs for installed Ubuntu kernel
KVER="$(ls -1 /lib/modules | sort -V | tail -n 1)"
echo "Generating Ubuntu initramfs for kernel ${KVER}..."
update-initramfs -c -k "${KVER}" || update-initramfs -u -k "${KVER}"

# Clean apt package caches to keep squashfs lean (keep apt lists so apt-cache policy works immediately!)
apt-get clean
rm -rf /var/tmp/* /tmp/* /var/log/*.log || true

# StormRaven voice: motd with attitude (plain-text fallback for logins)
$SUDO rm -f "${CHROOT_DIR}/etc/motd"
$SUDO tee "${CHROOT_DIR}/etc/motd" >/dev/null <<'MOTD'
  .__                      .__
  |__|_______   ____   __ |__| ________________
  |  \_  __ \_/ __ \ |  | |  | \__  \_  __ \
  |  ||  | \/\  ___/ |  |_|  |__/ __ \|  | \/
  |__||__|    \___  >____/____(____  /__|
                  \/               \/
  StormRaven OS 24.04 LTS (Ubuntu Noble)

  "The void does not crash. It remembers, and it deletes."

  The Nine Realms stand watch. The kernel is listening.
  Run 'stormraven status' to greet the Sovereign stack,
  or 'stormraven odin' to speak with Odin himself.
MOTD
EOF

# Remove policy-rc.d and set up clean resolv.conf
$SUDO rm -f "${CHROOT_DIR}/usr/sbin/policy-rc.d"
$SUDO rm -f "${CHROOT_DIR}/etc/resolv.conf"
$SUDO tee "${CHROOT_DIR}/etc/resolv.conf" >/dev/null <<'EOF'
nameserver 10.0.2.3
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF

# Unmount chroot virtual filesystems before mksquashfs
cleanup_mounts

echo "==> [6/7] Packing squashfs rootfs and staging kernel + initrd..."
VMLINUZ="$(ls -1 "${CHROOT_DIR}"/boot/vmlinuz-* | sort -V | tail -n 1)"
INITRD="$(ls -1 "${CHROOT_DIR}"/boot/initrd.img-* | sort -V | tail -n 1)"
$SUDO cp -f "${VMLINUZ}" "${ISO_STAGING}/casper/vmlinuz"
$SUDO cp -f "${INITRD}" "${ISO_STAGING}/casper/initrd"
$SUDO chmod 644 "${ISO_STAGING}/casper/vmlinuz" "${ISO_STAGING}/casper/initrd"

# Generate package manifest
$SUDO chroot "${CHROOT_DIR}" dpkg-query -W --showformat='${Package} ${Version}\n' > "${ISO_STAGING}/casper/filesystem.manifest"

$SUDO mksquashfs "${CHROOT_DIR}" "${ISO_STAGING}/casper/filesystem.squashfs" \
  -comp xz -b 1M -noappend -e boot

# Provide symlink in /live as well for compatibility
ln -sf ../casper/vmlinuz "${ISO_STAGING}/live/vmlinuz"
ln -sf ../casper/initrd "${ISO_STAGING}/live/initrd"
ln -sf ../casper/filesystem.squashfs "${ISO_STAGING}/live/filesystem.squashfs"

# StormRaven GRUB theme (gfxterm): background, Geist Mono fonts, menu styling
mkdir -p "${ISO_STAGING}/boot/grub/themes"
cp -r "${REPO_ROOT}/distro/grub-theme/stormraven" "${ISO_STAGING}/boot/grub/themes/"

cat > "${ISO_STAGING}/boot/grub/grub.cfg" <<'EOF'
set default=0
set timeout=5

insmod all_video
insmod gfxterm
insmod png
set gfxmode=1920x1080,1280x720,auto
set gfxpayload=keep
terminal_input console serial
if loadfont /boot/grub/themes/stormraven/geistmono-26.pf2; then
    loadfont /boot/grub/themes/stormraven/geistmono-20.pf2
    terminal_output gfxterm serial
    set theme=/boot/grub/themes/stormraven/theme.txt
else
    terminal_output console serial
fi

menuentry "StormRaven OS 24.04 - Ethereal Void" {
    echo "Rousing the raven... [Ymir core + Pantheon]"
    linux /casper/vmlinuz boot=casper quiet splash console=tty0 console=ttyS0,115200n8
    initrd /casper/initrd
}

menuentry "StormRaven OS 24.04 - All-Father Sight (Verbose / Serial)" {
    echo "Unsealing kernel telemetry... [Serial 115200n8]"
    linux /casper/vmlinuz boot=casper console=tty0 console=ttyS0,115200n8
    initrd /casper/initrd
}

menuentry "StormRaven OS 24.04 - Iron Ward (Safe Mode)" {
    echo "Entering Iron Ward fallback... [nomodeset / fail-safe]"
    linux /casper/vmlinuz boot=casper nomodeset noapic noapm nodma nomce nolapic nosmp console=tty0 console=ttyS0,115200n8
    initrd /casper/initrd
}
EOF

mkdir -p "${ISO_STAGING}/.disk"
echo "StormRaven OS 24.04 LTS (Ubuntu Noble) - Release amd64 ($(date -u +%Y%m%d))" > "${ISO_STAGING}/.disk/info"

echo "==> [7/7] Building hybrid BIOS/UEFI bootable ISO: ${OUTPUT_ISO}..."
grub-mkrescue -o "${OUTPUT_ISO}" "${ISO_STAGING}" -- -volid "STORMRAVEN_2404"
sha256sum "${OUTPUT_ISO}" | sed "s|${REPO_ROOT}/||" > "${OUTPUT_ISO}.sha256"

echo "==> Build complete!"
ls -lh "${OUTPUT_ISO}" "${OUTPUT_ISO}.sha256"
cat "${OUTPUT_ISO}.sha256"
