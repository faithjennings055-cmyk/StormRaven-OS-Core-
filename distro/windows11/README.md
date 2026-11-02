# StormRaven OS — Windows 11 Edition (`distro/windows11/`, Issue #63)

Brings the full **StormRaven OS: Infinity Protocol** experience to Windows 11 via two supported paths:

## Option 1: 1-Command Windows 11 Installer (Recommended)
Run in an Administrator PowerShell window on any Windows 11 PC or VM:
```powershell
irm https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/install-win11.ps1 | iex
```
Or from a local clone of `StormRaven-OS-Core-`:
```powershell
powershell -ExecutionPolicy Bypass -File .\distro\windows11\Install-StormRaven-Win11.ps1
```

### What it installs on Windows 11
1. **Native C# Kernel & Bifrost Gateway (`:8787` + Named Pipe IPC):** Builds and starts `StormRaven.Kernel.exe` with Helheim, Niflheim, and Muspelheim vaults under `C:\ProgramData\StormRaven\void`.
2. **Pre-sealed Luci Key:** Provisions `C:\ProgramData\StormRaven\Luci.key` (`SR-LUCI-INFINITY-WIN11-SOVEREIGN-KEY-v3.4`).
3. **`stormraven` CLI (`C:\Windows\System32\stormraven.cmd`):**
   - `stormraven status`
   - `stormraven realms`
   - `stormraven ai`
   - `stormraven luci`
   - `stormraven odin`
   - `stormraven desktop`
4. **Ethereal Void Windows 11 Theme:** Enables system/app dark mode, `#07030a` deep void background, centered Windows 11 taskbar, and creates the **StormRaven OS** desktop launcher.

## Option 2: Custom Windows 11 ISO (`autounattend.xml`)
Drop `distro/windows11/autounattend.xml` into the root of any Windows 11 23H2/24H2 ISO (or USB stick created with Rufus/Media Creation Tool) to automatically provision the `stormraven` administrator account (password: `Stormraven`) and run `Install-StormRaven-Win11.ps1` on first boot.
