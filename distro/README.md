# StormRaven OS — Distro Build Plan (Ubuntu 24.04 base)

Status: **plan only, no ISO built yet**. This directory holds the scaffold:
a systemd unit, a build script skeleton, and this plan.

## Feasibility verdict

**Feasible.** StormRaven is a normal userspace .NET 8 app + Python side; it
needs no kernel changes, so "StormRaven OS" is a *remastered Ubuntu*, not a
Linux-from-scratch kernel project. Ubuntu 24.04 (Noble) ships `dotnet-sdk-8.0`
and `dotnet-runtime-8.0` in its own repos (no Microsoft feed needed), Python 3.12
and SQLite by default, which removes the biggest dependency headache. The only
real work is: pick a build tool, bake a systemd unit, brand it, and automate.

## 1. Toolchain choice

Three viable routes for remastering Ubuntu 24.04 into a custom ISO:

| Route | What it is | Verdict |
|---|---|---|
| **live-build** (`lb config` / `lb build`) | Debian/Ubuntu's canonical tool; declarative `config/` tree (package lists, hooks, includes), builds ISO end-to-end | **Recommended.** Most reproducible, fully scriptable, committed to git |
| **Cubic** (GUI) | Chroot-based wizard over an existing Ubuntu ISO | Good for one-off manual experiments; not automatable; skip for CI |
| **debootstrap + manual squashfs/ISO assembly** | Roll the rootfs, squashfs it, copy casper dirs, run `xorriso` | Maximum control, maximum footguns; only if live-build fights us |

Plan: **live-build on a Ubuntu 24.04 build host** (the build must run on Ubuntu
24.04 so the `chroot_apt` base and host casper/xorriso versions match).

Build host setup:

```bash
sudo apt-get update
sudo apt-get install -y live-build xorriso squashfs-tools debootstrap \
  dosfstools mtools grub-pc-bin grub-efi-amd64-bin syslinux-common
```

## 2. Packages baked into the image

`config/package-lists/stormraven.list.chroot`:

```
# Runtime for the StormRaven kernel
dotnet-sdk-8.0          # noble repo; swap to dotnet-runtime-8.0 for a smaller image later
python3 python3-venv python3-pip
sqlite3 libsqlite3-0

# Desktop environment (choice: GNOME matches Ubuntu default; XFCE for ~1.2GB less)
ubuntu-desktop-minimal   # or: xubuntu-core for the lean option

# Boot/branding plumbing we replace
plymouth plymouth-theme-ubuntu-logo
network-manager
openssh-server
```

Notes:
- GNOME `ubuntu-desktop-minimal` final ISO ≈ 3.5–4 GB. XFCE variant lands ≈ 2–2.5 GB.
- The .NET app is built once by the build script (`dotnet publish -c Release -r linux-x64 --self-contained false`) and installed to `/opt/stormraven/`.
- `StormRaven.Python/` scripts are copied to `/opt/stormraven/python/` with `python3` from the base image; no venv needed if only stdlib is used (verify `odin.py` imports before freezing the package list).

## 3. Systemd service shipping

Debian-style packages or live-build hooks drop unit files into the chroot's
`/etc/systemd/system/`; `systemctl enable` inside the chroot creates the boot
symlink. See `systemd/stormraven-kernel.service` in this directory (covers the
kernel + Bifrost gateway on :8787 via the kernel's own hosting; if the gateway
runs as a separate process, add a second unit `stormraven-bifrost.service`
chained with `After=/Requires=`).

Install via a live-build hook `config/hooks/0100-stormraven.chroot`:

```bash
#!/bin/sh
set -e
install -D -m 644 /usr/share/stormraven/systemd/stormraven-kernel.service \
  /etc/systemd/system/stormraven-kernel.service
systemctl enable stormraven-kernel.service
# Open the gateway port
iptables -I INPUT -p tcp --dport 8787 -j ACCEPT || true
```

Firewall alternative for 24.04: ship a `ufw allow 8787` rule instead of raw iptables.

## 4. Branding / customization

| Element | Mechanism |
|---|---|
| Boot splash | Custom Plymouth theme: copy `plymouth-theme-ubuntu-logo`, edit `*.plymouth` + `*.script` to StormRaven art, install to `/usr/share/plymouth/themes/stormraven/`, set `default-theme=stormraven` in `/etc/plymouth/plymouthd.conf` |
| GRUB menu | `config/includes.chroot/etc/default/grub` (GRUB_TIMEOUT, menu name) plus a custom background at `/boot/grub/` |
| Wallpaper | `/usr/share/backgrounds/stormraven.png` + gsettings override via a dconf profile in `/etc/dconf/profile/user` and `/etc/dconf/db/local.d/00-wallpaper` |
| GDM theme | GNOME 46 (24.04) GDM theme is compiled into `ubuntu.css`/gdm resource; realistic path is overriding `/usr/share/gnome-shell/gnome-shell-theme.gresource` or shipping a `/etc/gdm3/` greeter config — budget a full day, it's the fiddliest branding item |
| MOTD | `config/includes.chroot/etc/motd` and a `/etc/update-motd.d/90-stormraven` script (shows kernel status + gateway health) |
| Hostname | `config/includes.chroot/etc/hostname` = `stormraven` |
| ISO volume label / installer name | `lb config --iso-volume "StormRavenOS" --iso-application "StormRaven OS 24.04"` |

## 5. Build script

See `build.sh` in this directory (skeleton). Happy path:

```bash
cd distro && sudo ./build.sh           # produces distro/build/stormraven-os-24.04-amd64.iso
```

## 6. Disk / time / hardware requirements

- Build host: **50 GB free disk** (chroot ~6 GB + caches + ISO staging), 8 GB RAM minimum.
- First full `lb build`: **30–60 min** on a 4–8 vCPU box (debootstrap + package install dominates). Subsequent rebuilds with apt cache intact: **5–15 min**.
- ISO size estimate: **3.5–4 GB** (GNOME) or **2–2.5 GB** (XFCE), of which StormRaven's own payload is <100 MB.
- CI-able: live-build is a pure CLI, so it runs in a GitHub Actions runner with `ubuntu-24.04` image if a self-hosted runner with 50 GB disk is available (GitHub hosted runners have ~14 GB free — tight; use the lean package list or an artifact-caching strategy).

## 7. Phased timeline (realistic)

| Phase | Work | Time |
|---|---|---|
| 0 | Scaffold (this dir), unit file, build script | done / 0.5 h |
| 1 | Vanilla live-build Ubuntu 24.04 ISO boots in QEMU (no customization) | 0.5 day |
| 2 | StormRaven payload: `dotnet publish`, install to /opt, systemd unit enabled, :8787 reachable from host | 0.5–1 day |
| 3 | Branding: Plymouth, wallpaper, MOTD, hostname, GRUB label | 1 day |
| 4 | GDM theme + polish; installer (Ubiquity/Subiquity) defaults point at StormRaven branding | 1–2 days |
| 5 | CI + signed ISO artifact, release | 0.5 day |

**Total: roughly 3–5 working days** for a solid first ISO; ~1 day for a quick "bootable proof of concept" (Phases 1–2 only).

## 8. Risks / gotchas

- live-build version drift: pin the `live-build` version used by CI; hooks are shell and easy to get wrong silently — log `chroot` hook failures.
- Boot in UEFI **and** BIOS in QEMU before shipping (`qemu-system-x86_64 -m 4G -cdrom build/*.iso` plus an OVMF variant).
- GDM/gresource branding breaks across GNOME upgrades; keep it as an override, not a replacement.
- The gateway binding :8787 must tolerate running as a non-root service user (`DynamicUser=yes` or a dedicated `stormraven` user).
- Squashfs is read-only at runtime: any runtime-writable state the kernel needs (SQLite db) must target a persistent path (home dir or `/var/lib/stormraven/`), created by the unit's pre-start.
