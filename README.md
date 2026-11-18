# StormRaven OS

**StormRaven OS is a hardened, privacy-focused operating system you can run from a USB stick — built on Ubuntu 26.04 LTS, with a companion Windows 11 edition.**

---

## ⬇️ Download

**Everything is on one page: https://echo-at-faith-s-workspace-2.skydive.app/download**

There are exactly three choices. Pick the one that matches your computer.

| | For | Size |
|---|---|---|
| **Ubuntu Edition** | Laptops and desktops, 4GB+ RAM | ~1.7 GB |
| **Windows 11 Edition** | PCs that need Windows, or dual-boot | ~6.8 GB |
| **Tiny Edition** | Surface 3 and 32-bit UEFI tablets | ~470 MB |

## 💾 Put it on a USB stick

You need one empty USB stick, 8GB or bigger. **Everything on the stick will be erased.**

1. **Windows** — install [Rufus](https://rufus.ie), open it, choose your stick, click **SELECT** and pick the downloaded file, click **START**.
2. **Mac** — install [balenaEtcher](https://etcher.balena.io), click **Flash from file**, pick the downloaded file and your stick, click **Flash**.
3. **Linux** — `lsblk` to find your stick, then `sudo dd if=THE-FILE.iso of=/dev/sdX bs=4M status=progress`
4. **Boot it** — restart with the stick plugged in and tap the boot-menu key as it powers on: **F12**, **F9** or **Esc** on most PCs, or **hold Volume-Down** on a Surface. Choose the USB stick by name.

Booting the stick runs the live system only. It does not touch your files until you choose to install.

## ✅ Verify your download

Every release has a `.sha256` file next to it. Compare it before you flash:

```bash
sha256sum StormRavenOS-*.iso          # Linux / Mac
certutil -hashfile StormRavenOS-*.iso SHA256   # Windows
```

The output must match the checksum shown on the download page exactly.

## 🔐 What's inside

- **WireGuard VPN** built in, with a kill switch
- **Virtual machines** — KVM/QEMU and virt-manager preinstalled
- **Forensic tools** for disk and memory acquisition, with chain-of-custody hashing
- **A command gate** (Heimdall) that checks every system command before it runs
- **A tarpit** (Demogorgon) that catches intruders and holds them
- **A phone app** that can actually control the machine

The OS speaks Norse mythology in its interface, but the code underneath is ordinary, auditable Linux.

## 🛠 Building it yourself

```bash
sudo ./distro/build-ubuntu-iso.sh     # produces StormRavenOS-*.iso + .sha256
```

Requires Debian/Ubuntu x86_64 with `debootstrap`, `squashfs-tools`, `xorriso`, and `grub-pc-bin`.

## 📚 More

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — how the system is put together
- [SECURITY.md](SECURITY.md) — reporting a vulnerability
- [TERMS_AND_COPYRIGHT.md](TERMS_AND_COPYRIGHT.md) — licensing

## ⚠️ Before you install

This is beta software. Back up anything important first, and expect rough edges — the project is under active development and the download links change as builds land.
