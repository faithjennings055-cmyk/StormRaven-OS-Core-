# StormRaven OS — Ubuntu 26.04 "Resolute Raccoon" with Mac-style desktop

Build config for the live-build ISO: Ubuntu 26.04 LTS base, GNOME 50 with
mac-style tuning (Ubuntu Dock at bottom, light theme, WhiteSur icons + cursors,
Inter fonts, left window buttons, custom StormRaven wallpaper + MOTD), and the
StormRaven kernel + Bifrost gateway (:8787) auto-starting as a systemd service.

## Build

    sudo apt install live-build debootstrap squashfs-tools xorriso
    # debootstrap needs resolute script (debootstrap >= 1.0.140)
    # ubuntu-archive-keyring.gpg must be in /usr/share/keyrings

    # 1. publish the kernel payload (self-contained linux-x64):
    #    dotnet publish -c Release -r linux-x64 --self-contained true -o payload
    # 2. put payload + stormraven-kernel.service + wallpapers into
    #    config/hooks/live/payload/ (hook copies it to /opt/stormraven)
    # 3. build:
    lb config --distribution resolute --mode ubuntu \
      --archive-areas "main universe restricted multiverse" \
      --keyring-packages "ubuntu-keyring" \
      --parent-mirror-bootstrap "http://archive.ubuntu.com/ubuntu/" \
      --parent-mirror-chroot "http://archive.ubuntu.com/ubuntu/" \
      --parent-mirror-binary "http://archive.ubuntu.com/ubuntu/" \
      --mirror-bootstrap "http://archive.ubuntu.com/ubuntu/" \
      --mirror-chroot "http://archive.ubuntu.com/ubuntu/" \
      --mirror-chroot-security "http://security.ubuntu.com/ubuntu/" \
      --mirror-binary "http://archive.ubuntu.com/ubuntu/" \
      --mirror-binary-security "http://security.ubuntu.com/ubuntu/" \
      --iso-volume "StormRaven OS 26.04" --iso-application "StormRaven OS"
    sudo lb build

## Notes from the build
- lb's ubuntu mode needs `--keyring-packages "ubuntu-keyring"` (resolute dropped debian-archive-keyring)
- kernel: LB_LINUX_PACKAGES="linux-image" + LB_LINUX_FLAVOURS="generic" (Debian's linux-image-amd64 doesn't exist in Ubuntu)
- efi.img FAT sizing needs extra headroom with GNOME 50 grub (patch /usr/lib/live/build/binary_grub-efi +55 → +2000)
- BUILD_WITH_CHROOT=true copies the chroot into itself before inner mksquashfs; hooks/includes must land before that copy — verify /opt/stormraven + icons are inside chroot/chroot before the rootfs stage

## Verified
- boots in QEMU (UEFI + direct kernel), hostname stormraven, branded MOTD
- stormraven-kernel.service active, gateway on 0.0.0.0:8787
- host→VM gateway health, tab ingest → FOCUS decision, ping — all working
- Ubuntu Dock present, dconf mac-style profile compiled, WhiteSur icons/cursors shipped
