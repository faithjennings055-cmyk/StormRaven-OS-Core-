# StormRaven OS v3.0.0 — Ubuntu 24.04 LTS (Noble Numbat) Live ISO

This branch contains the bootable **StormRaven OS 24.04 LTS (Ubuntu Noble Numbat)** Live ISO (`StormRavenOS-ubuntu-24.04-amd64.iso`, 221 MB), split into `<90 MB` parts so it can be cloned directly via Git without LFS.

## Reassemble & Verify

```bash
git clone -b iso-release https://github.com/faithjennings055-cmyk/StormRaven-OS-Core-
cd StormRaven-OS-Core-/iso-release
cat StormRavenOS-ubuntu-24.04-amd64.iso.part* > StormRavenOS-ubuntu-24.04-amd64.iso
sha256sum -c StormRavenOS-ubuntu-24.04-amd64.iso.sha256
```

## Booting in QEMU or on Hardware

```bash
qemu-system-x86_64 -m 2048 -smp 2 \
  -cdrom StormRavenOS-ubuntu-24.04-amd64.iso \
  -net nic -net user,hostfwd=tcp::18787-:8787 \
  -nographic -serial mon:stdio
```

## Live Credentials & Services

- **Auto-login:** `ubuntu` on `tty1` and serial console `ttyS0`
- **Logins (all passwordless `sudo`):**
  - `ubuntu` / `stormraven`
  - `stormraven` / `stormraven`
  - `user` / `live`
- **Bifrost HTTP/WebSocket Gateway:** `http://localhost:8787/health` (`stormraven-kernel.service`)
- **StormRaven CLI:** `stormraven status`, `stormraven health`, `stormraven decisions`, `stormraven odin`
- **Pantheon Python Core:** `python3 /opt/stormraven/python/odin.py`
- **Companion Webapp (PWA):** `/opt/stormraven/webapp/`
