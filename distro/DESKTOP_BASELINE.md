# StormRaven OS 24.04 LTS — Modern Desktop Baseline & Built-in Subsystems

## 1. Built-in WireGuard VPN & Kill-Switch (`stormraven-vpn`, Issue #23)
- **Native Stack:** `wireguard-tools`, `iptables`, `nftables`, `qrencode` preinstalled in the live/install rootfs.
- **CLI & Daemon Control:** `/usr/local/bin/stormraven-vpn` (`status`, `up`, `down`, `import <conf>`, `qr`, `killswitch on|off`).
- **Kill-Switch:** `STORMRAVEN_KILLSWITCH` chain blocks all non-`wg0` and non-loopback egress when enabled, preventing traffic leaks on tunnel drop.
- **Dashboard & Bifrost Integration:** `vpn_status`, `vpn_connect`, `vpn_disconnect`, and `vpn_killswitch` intents exposed via Bifrost Gateway (`:8787`).

## 2. Built-in Forensic Subsystems (`stormraven-forensics`, Issue #24)
- **Boot Menu:** Dedicated GRUB entry `StormRaven OS 24.04 Forensic Mode (Read-Only / Write-Blocker)` passes `ro forensic=1 noswap noautomount`.
- **Preinstalled Toolset:** `dc3dd`, `sleuthkit` (`mmls`, `fls`), `binwalk`, `foremost`, `yara`, `ewf-tools`, `auditd`, `hashdeep`, `testdisk`, `exiftool`.
- **Chain-of-Custody Workflow:** `/usr/local/bin/stormraven-forensics acquire-disk <dev> <case-id>` produces a raw image alongside a SHA-256 verified `.manifest.json`; `timeline` exports structured journald/auditd logs; `verify` validates image integrity against the manifest.

## 3. Built-in KVM/QEMU Hypervisor (`stormraven-vm`, Issue #25)
- **Preinstalled Stack:** `qemu-system-x86`, `qemu-utils`, `libvirt-daemon-system`, `libvirt-clients`, `virt-manager`, `ovmf`.
- **Nested Virtualization:** Enabled out of the box via `/etc/modprobe.d/stormraven-kvm.conf` (`options kvm_intel nested=1`, `options kvm_amd nested=1`).
- **Storage & Passthrough:** Default storage pool preconfigured at `/var/lib/libvirt/images`; `/usr/local/bin/stormraven-vm` supports `status`, `init-pool`, `snapshot`, `restore`, and `usb-attach <vm> <vid:pid>`.

## 4. Modern Desktop Baseline Audit Checklist (Issue #26 — Verified via `stormraven baseline-audit`)
| Subsystem | Packages / Stack in ISO | Verification Command | Status |
|---|---|---|---|
| **Networking & Firewall** | `network-manager`, `ufw` (default deny incoming, allow outgoing), Wi-Fi/Eth + hotspot sharing | `stormraven baseline-audit` / `ufw status` | VERIFIED |
| **Bluetooth** | `bluez`, `blueman`, A2DP/HFP PipeWire audio profiles | `bluetoothctl --version` | VERIFIED |
| **Audio** | `pipewire`, `wireplumber`, `pipewire-pulse`, `alsa-utils` | `pipewire --version` | VERIFIED |
| **Printing & Scanning** | `cups`, `cups-client`, `sane-utils`, driverless IPP auto-detect | `lpstat -r` / `scanimage -L` | VERIFIED |
| **Multimedia & Browser** | `ffmpeg`, GStreamer codec suite, MPV/media playback, PWA desktop shell | `ffmpeg -version` | VERIFIED |
| **Office Suite** | `libreoffice` suite | `libreoffice --version` | VERIFIED |
| **Updates & Backups** | `unattended-upgrades`, `timeshift`, `rsync`, Niflheim snapshot integration | `timeshift --list` / `rsync --version` | VERIFIED |
| **Suspend/Resume & RTC** | `systemd-logind` lid/sleep hooks, UTC hardware clock (`hwclock`), ACPI power management | `loginctl show-seat seat0` | VERIFIED |
| **Peripherals & Hotplug** | `udev`, `v4l-utils` (webcam), DRM/KMS multi-monitor & USB-C dock hotplug | `udevadm info --export-db` | VERIFIED |

## 5. System-Wide OS Voice & Off-Switch (Issue #28)
- **Config Flag:** `/etc/stormraven/voice.conf` (`STORMRAVEN_VOICE=1` default Sovereign voice; `STORMRAVEN_VOICE=0` or `stormraven voice off` for plain technical output).
- **Boot & Login:** Plymouth splash (`stormraven-void.script`) and `/etc/update-motd.d/10-stormraven-voice` emit rotating Norse-tech taglines from Hlidskjalf.
- **CLI & Pantheon:** `stormraven` CLI (`status`, `voice`, `baseline-audit`, `realms`) and `void-shell.py` respect `STORMRAVEN_VOICE`.
