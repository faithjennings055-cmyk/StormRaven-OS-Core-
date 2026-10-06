#!/bin/bash
# StormRaven OS ISO build script — live-build on Ubuntu 24.04
# Skeleton: Phase 0. Run as root on a Ubuntu 24.04 build host with >=50GB free.
set -euo pipefail

ISO_NAME="stormraven-os-24.04"
VERSION="$(date +%Y%m%d)"
BUILD_DIR="$(cd "$(dirname "$0")" && pwd)/build"
KERNEL_REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# 1. Prereqs (idempotent)
apt-get update
apt-get install -y live-build xorriso squashfs-tools debootstrap \
  dosfstools mtools grub-pc-bin grub-efi-amd64-bin dotnet-sdk-8.0

# 2. Build the StormRaven kernel payload
echo "==> dotnet publish"
cd "$KERNEL_REPO_DIR"
dotnet publish StormRaven.Kernel.csproj -c Release -r linux-x64 --self-contained false \
  -o "$BUILD_DIR/payload/stormraven"

# 3. Assemble chroot payloads to be installed into the image
#    /opt/stormraven/{StormRaven.Kernel.dll,deps,runtimeconfig}
#    /opt/stormraven/python/  (StormRaven.Python/*.py)
#    /usr/share/stormraven/systemd/stormraven-kernel.service
mkdir -p "$BUILD_DIR/payload/python" "$BUILD_DIR/payload/systemd"
cp -r "$KERNEL_REPO_DIR/StormRaven.Python/"*.py "$BUILD_DIR/payload/python/"
cp distro/systemd/stormraven-kernel.service "$BUILD_DIR/payload/systemd/"

# 4. live-build config
rm -rf "$BUILD_DIR/lb" && mkdir -p "$BUILD_DIR/lb"
cd "$BUILD_DIR/lb"
lb config \
  --distribution noble \
  --archive-areas "main restricted universe multiverse" \
  --iso-application "StormRaven OS 24.04" \
  --iso-volume "StormRavenOS" \
  --iso-publisher "StormRaven;https://github.com/faithjennings055-cmyk/StormRaven-OS-Core-" \
  --apt-recommends false

# TODO (Phase 1-4): copy in config/package-lists, config/hooks, config/includes
#   package-lists/stormraven.list.chroot  (dotnet-sdk-8.0, python3, ubuntu-desktop-minimal, ...)
#   hooks/0100-stormraven.chroot          (install payload, enable systemd unit, ufw allow 8787)
#   includes.chroot/etc/hostname, /etc/motd, wallpapers, plymouth theme, dconf

# 5. Build the ISO
echo "==> lb build (this takes 30-60 min on first run)"
# lb build 2>&1 | tee "$BUILD_DIR/lb.log"

# 6. Verify: boot in QEMU before shipping
# qemu-system-x86_64 -m 4G -cdrom images/*.iso -boot d   (BIOS)
# qemu-system-x86_64 -m 4G -cdrom images/*.iso -boot d -bios /usr/share/ovmf/OVMF.fd (UEFI)

echo "TODO: uncomment lb build after config tree is complete (Phase 1)."
