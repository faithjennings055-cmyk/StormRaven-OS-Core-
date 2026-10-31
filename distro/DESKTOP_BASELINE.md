# StormRaven OS 24.04 LTS — Modern Desktop Baseline & Built-in Subsystems

## 1. Built-in WireGuard VPN & Kill-Switch (`stormraven-vpn`, Issue #23)
- **Native Stack:** `wireguard-tools`, `iptables`, `nftables`, `qrencode` preinstalled in the live/install rootfs.
- **CLI & Daemon Control:** `/usr/local/bin/stormraven-vpn` (`status`, `up`, `down`, `import <conf>`, `qr`, `killswitch on|off`).
- **Kill-Switch:** `STORMRAVEN_KILLSWITCH` chain blocks all non-`wg0` and non-loopback egress when enabled, preventing traffic leaks on tunnel drop.
- **Dashboard & Bifrost Integration:** `vpn_status`, `vpn_connect`, `vpn_disconnect`, and `vpn_killswitch` intents exposed via Bifrost Gateway (`:8787`).

## 2. Built-in Forensic Subsystems (`stormraven-forensics`, Issue #24)
- **Boot Menu:** Dedicated GRUB entry `StormRaven OS 24.04 Forensic Mode (Read-Only / Write-Blocker)` passes `ro forensic=1 noswap noautomount`.
- **Preinstalled Toolset:** `dc3dd`, `sleuthkit` (`mmls`, `fls`), `binwalk`, `foremost`, `yara`, `ewf-tools`, `auditd`.
- **Chain-of-Custody Workflow:** `/usr/local/bin/stormraven-forensics acquire-disk <dev> <case-id>` produces a raw image alongside a SHA-256 verified `.manifest.json`; `timeline` exports structured journald/auditd logs; `verify` validates image integrity against the manifest.

## 3. Built-in KVM/QEMU Hypervisor (`stormraven-vm`, Issue #25)
- **Preinstalled Stack:** `qemu-system-x86`, `qemu-utils`, `libvirt-daemon-system`, `libvirt-clients`, `virt-manager`.
- **Nested Virtualization:** Enabled out of the box via `/etc/modprobe.d/stormraven-kvm.conf` (`options kvm_intel nested=1`, `options kvm_amd nested=1`).
- **Storage & Passthrough:** Default storage pool preconfigured at `/var/lib/libvirt/images`; `/usr/local/bin/stormraven-vm` supports `status`, `init-pool`, `snapshot`, `restore`, and `usb-attach <vm> <vid:pid>`.

## 4. Modern Desktop Baseline Audit (Issue #26)
- **Networking & Firewall:** `network-manager` + `ufw` preinstalled with sane default policy.
- **Bluetooth:** `bluez` stack included.
- **Audio:** `pipewire` + `wireplumber` low-latency audio routing.
- **Printing:** `cups-client` included.
- **Updates & Sync:** `unattended-upgrades` + `rsync` preinstalled.
