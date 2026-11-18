# StormRaven OS

**StormRaven OS is a hardened, privacy-focused operating system you can run from a USB stick — built on Ubuntu 26.04 LTS, with a companion Windows 11 edition.**

---

## ⬇️ Download

**Everything is on one page: https://echo-at-faith-s-workspace-2.skydive.app/download**

There are exactly three choices. Pick the one that matches your computer.

| | For | Size | Flash Note |
|---|---|---|---|
| **Ubuntu Edition** (`Ubuntu 26.04 LTS · amd64`) | Laptops and desktops, 4GB+ RAM | ~1.7 GB | Rufus, balenaEtcher, or `dd` |
| **Windows 11 Edition** (`Windows 11 25H2 · x64`) | PCs that need Windows, or dual-boot | ~6.8 GB | **Rufus or balenaEtcher only** (no raw `dd`) |
| **Tiny Edition** (`32-bit UEFI / i386`) | Older 32-bit PCs and 32-bit UEFI tablets *(Surface 3 uses Micro SD payload `#106`)* | ~470 MB | **Rufus or balenaEtcher** (do not unzip onto stick) |

## 💾 Put it on a USB stick

You need one empty USB stick, 8GB or bigger. **Everything on the stick will be erased.**

1. **Windows** — install [Rufus](https://rufus.ie), open it, choose your stick, click **SELECT** and pick the downloaded file, click **START**.
2. **Mac** — install [balenaEtcher](https://etcher.balena.io), click **Flash from file**, pick the downloaded file and your stick, click **Flash**.
3. **Linux (Ubuntu & Tiny Editions only)** — `lsblk` to find your stick, then `sudo dd if=THE-FILE.iso of=/dev/sdX bs=4M status=progress` *(do not use `dd` for the Windows 11 ISO — it has no MBR/GPT partition table of its own; use Rufus, balenaEtcher, or `distro/make-ventoy-usb.sh`)*.
4. **Boot it** — restart with the stick plugged in and tap the boot-menu key as it powers on: **F12**, **F9** or **Esc** on most PCs, or **hold Volume-Down** on a Surface. Choose the USB stick by name.

Booting the stick runs the live system only. It does not touch your files until you choose to install.

## ✅ Verify your download

Every release has a `.sha256` file next to it. Compare it before you flash:

```bash
sha256sum StormRavenOS-*.iso                   # Linux / Mac
certutil -hashfile StormRavenOS-*.iso SHA256   # Windows
```

The output must match the checksum shown on the download page exactly.

## 🔐 What's inside

- **WireGuard VPN** built in, with a kill switch
- **Virtual machines** — KVM/QEMU and virt-manager preinstalled
- **Forensic tools** for disk and memory acquisition, with chain-of-custody hashing
- **Full desktop** — browser, office suite, terminal, file manager, media player
- **Local health service** on `http://localhost:8787/health`

## 📚 More

- [Architecture & design notes](docs/ARCHITECTURE.md)
- [Building the ISOs from source](distro/README.md)
- [Security & vulnerability reporting](SECURITY.md)
- [License & copyright](TERMS_AND_COPYRIGHT.md)
