# StormRaven OS 24.04 LTS (Ubuntu Noble Numbat) — Live Distro

This directory contains the reproducible **Ubuntu 24.04 LTS (`noble`)** live distribution configuration and ISO builder for **StormRaven OS**.

## What is Baked into the Ubuntu 24.04 Live ISO

- **Base OS:** Ubuntu 24.04 LTS (`noble`, `http://archive.ubuntu.com/ubuntu/`, `main restricted universe multiverse`)
- **Kernel & Init:** Ubuntu 6.8 Generic Linux kernel (`linux-image-generic` / `linux-image-virtual`), `casper` live boot, `systemd` (`systemd-sysv`), `systemd-networkd` + `systemd-resolved` DHCP networking
- **StormRaven Native Kernel & Bifrost Gateway:**
  - Installed at `/opt/stormraven/StormRaven.Kernel` (with `Schema.sql` and self-contained .NET 8 runtime libraries)
  - Managed by `stormraven-kernel.service` (auto-starts at boot, listens on `http://*:8787`, stores SQLite state in `/var/lib/stormraven/kernel.db`)
- **StormRaven Python Pantheon (`/opt/stormraven/python/`):**
  - `odin.py`, `thor.py`, `freya.py`, `heimdall.py`, `bifrost.py`, `saga.py`, `ragnarok.py`, `deadman.py`, `shadow_log.py`, `solomon.py`, `void_viz.py`, `constants.py`, `heketa.py`, `luci.py`, `lynn.py`
  - Pre-installed with Python 3.12 (`python3`, `python-is-python3`, `python3-rich`, `python3-psutil`, `sqlite3`)
- **StormRaven Companion Webapp (PWA):**
  - Installed at `/opt/stormraven/webapp/`
- **StormRaven CLI (`/usr/local/bin/stormraven`):**
  - `stormraven status` — Distro, kernel, service status, and live gateway health/state
  - `stormraven health` — Raw JSON from `GET /health`
  - `stormraven state` — Raw JSON from `GET /state`
  - `stormraven decisions` — Raw JSON from `GET /decisions`
  - `stormraven tabs` — Raw JSON from `GET /tabs`
  - `stormraven ping` — Sends `{"intent":"ping"}` to `POST /commands`
  - `stormraven odin` — Launches the interactive Python Pantheon (`odin.py`)
- **Live Credentials & Auto-Login:**
  - Auto-logs in on `tty1` and serial console `ttyS0` as `ubuntu`
  - `ubuntu` / `stormraven` (passwordless `sudo`)
  - `stormraven` / `stormraven` (passwordless `sudo`)
  - `user` / `live` (passwordless `sudo`)

## Building the ISO

Run the self-contained builder script on any Debian/Ubuntu x86_64 host:

```bash
sudo ./distro/build-ubuntu-iso.sh
```

This produces:
- `StormRavenOS-ubuntu-24.04-amd64.iso`
- `StormRavenOS-ubuntu-24.04-amd64.iso.sha256`

A declarative `live-build` configuration targeting Ubuntu 24.04 (`noble`) is also maintained under `distro/live-build/config/`.

## Booting & Verifying in QEMU

```bash
qemu-system-x86_64 \
  -m 2048 -smp 2 \
  -cdrom StormRavenOS-ubuntu-24.04-amd64.iso \
  -net nic -net user,hostfwd=tcp::18787-:8787 \
  -nographic -serial mon:stdio
```

Once booted, verify from the host:

```bash
curl http://localhost:18787/health
curl -X POST http://localhost:18787/tabs \
  -H "Content-Type: application/json" \
  -d '[{"id":"tab-1","title":"StormRaven Ubuntu 24.04","url":"https://ubuntu.com","isCurrent":true,"isAudible":false}]'
curl http://localhost:18787/decisions
```
