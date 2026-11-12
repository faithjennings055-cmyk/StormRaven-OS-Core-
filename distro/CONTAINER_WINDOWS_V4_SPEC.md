# StormRaven OS: Container-Native Windows Distribution (`dockur/windows` Base — Issue #98)

## 1. Executive Summary & Positioning

StormRaven OS ships across **three complementary distributions** (not a replacement for the bare-metal Windows 11 25H2 Ymir ISO):

| Distribution | Target Environment | Hardware / GPU Access | Boot & Provisioning Path |
| :--- | :--- | :--- | :--- |
| **1. StormRaven OS: Ubuntu Ymir Edition ISO** | Bare-metal laptops/workstations, Ventoy USB, dual-boot | Direct bare-metal Ring-0 kernel, GPU, Wi-Fi, NVMe | `distro/build-ubuntu-iso.sh` / `distro/repack-ubuntu-iso.sh` (`#100`) |
| **2. StormRaven OS: Windows 11 25H2 Ymir ISO** | Bare-metal Windows 11 installs, dual-boot partitions | Direct bare-metal GPU, disk, TPM/SecureBoot bypass (`LabConfig` `#97`) | `distro/build-win11-iso.sh` / `distro/windows11/Build-StormRaven-Win11-ISO.ps1` |
| **3. StormRaven OS: Container-Native Windows (v4.0 RavenNest Container)** | Docker / Podman / KVM servers, cloud hosts, instant local spins without re-partitioning or USB flashing | KVM/QEMU virtualized (`/dev/kvm` passthrough), Web/noVNC (`:8006`) + FreeRDP (`:3389`) + Bifrost Gateway (`:3887` / `:8787`) | `distro/containers/dockur-windows/docker-compose.yml` + `stormraven-vm dockur` (`#98`) |

---

## 2. Architecture: How `dockur/windows` Layers with StormRaven Ymir

`dockur/windows` is an OCI container that boots an unattended Windows 11 QEMU/KVM virtual machine inside Docker/Podman and exposes a live web display (`:8006`) and FreeRDP (`:3389`).

StormRaven OS layers our Sovereign Ymir stack onto `dockur/windows` via three mechanisms:

1. **Checksum-Verified Base ISO or Auto-Unattended Provisioning:**
   - If `/var/lib/stormraven/iso/StormRavenOS-Win11-Ymir-v3.9.0-amd64.iso` (or `~/Documents/StormRavenOS-Win11-Ymir-v3.9.0-amd64.iso`) is present, `stormraven-vm dockur` verifies its `.sha256` sidecar (`sha256sum -c`) before mounting it into `/custom.iso`.
   - When booting stock Windows 11 (`VERSION: "11"`), `distro/windows11/autounattend.xml` (`#97`, zero plaintext credentials, `LabConfig` TPM/SecureBoot/RAM/CPU bypass) and the OEM provisioning bundle (`distro/containers/dockur-windows/oem/install.bat`) are bind-mounted into `/oem`.
2. **Automatic OEM Post-Install Layer (`C:\OEM\install.bat`):**
   - Executed automatically by `dockur/windows` on first boot.
   - Verifies the SHA-256 sidecar of `install-win11.ps1` (`Get-FileHash -Algorithm SHA256`) before invoking PowerShell — zero blind `irm | iex` execution.
   - Installs the StormRaven Pantheon CLI (`stormraven`, `freya`, `cortana`, `wsu`, `moov-ai`), per-install 256-bit `Luci.key`, Ymir Glass dark theme, Skydive Desktop/CLI wrapper (`#103`), and starts the Bifrost Gateway inside the VM on `:3887` and `:8787`.
3. **WinApps & WSU Sovereign Cell Compatibility (`#96`):**
   - Port `3389/tcp` is bound to `127.0.0.1:3389` (or configurable `STORMRAVEN_DOCKUR_RDP_PORT`) and verified via `/cert:tofu` (never `/cert:ignore`) with credentials piped via `/from-stdin` (`FREERDP_ASKPASS`).

---

## 3. Install Footprint & Licensing Implications

- **Container Image Footprint:** `dockur/windows:latest` OCI wrapper is ~450 MB (QEMU/KVM + OVMF UEFI + noVNC + Samba).
- **Windows 11 Media & Disk Footprint:**
  - Base Windows 11 25H2 ISO download/mount: ~5.4 GB – 6.5 GB.
  - Installed qcow2 sparse disk volume (`/storage`): ~14 GB initial footprint (configurable `DISK_SIZE: "64G"` thin-provisioned).
  - Recommended RAM / CPU allocation: `RAM_SIZE: "4G"` (minimum 2 GB with `LabConfig` bypass), `CPU_CORES: "4"`.
- **Microsoft Licensing:**
  - `dockur/windows` fetches official Microsoft evaluation/retail installation media when no custom ISO is mounted.
  - Per-instance Windows 11 licensing still applies according to Microsoft's End User License Agreement (EULA); StormRaven OS does not bundle KMS activators or unauthorized product keys in `autounattend.xml`.

---

## 4. One-Command Launch & Verification

```bash
# Check status and container readiness (JSON)
stormraven-vm dockur-status

# Start the container-native StormRaven Windows 11 Ymir node
stormraven-vm dockur-up

# Verify stormraven CLI & Bifrost gateway inside the container VM
curl -fsSL http://127.0.0.1:3887/health
```
