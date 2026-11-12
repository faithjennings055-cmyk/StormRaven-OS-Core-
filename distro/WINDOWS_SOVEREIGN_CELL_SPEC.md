# StormRaven OS — Windows Subsystem for Ubuntu (WSU) & Windows Sovereign Cell Specification (#96)

## 1. Architectural Overview ("Reverse WSL" under Zero-Trust)
StormRaven OS provides first-class execution of Windows applications and binaries inside the Ubuntu edition through a dual-tier **Windows Subsystem for Ubuntu (`stormraven-wsu` / `wsu`)** architecture that preserves the 1% Margin for Error and NIST SP 800-207 Zero-Trust boundary:

1. **Tier 1 — Primary Path: The RavenNest Windows 11 Sovereign Cell (`wsu cell start|stop|status`)**
   - Encapsulates the **StormRaven OS Windows 11 (Ymir Edition)** image inside an isolated KVM/QEMU hypervisor cell managed directly from the **RavenNest Virtual Server** panel.
   - **Seamless Application Windowing:** Windows GUI applications stream onto the Ubuntu X11/Wayland desktop as native-feeling floating windows over a loopback-only FreeRDP RemoteApp channel (`xfreerdp /app:`).
   - **Heimdall-Gated Host-Guest Diode:** The Windows Sovereign Cell has zero unauthenticated access to the Ubuntu host filesystem or network. Every host-guest IPC request crosses the **Bifrost Gateway** (`:8787`) and must pass the **Heimdall 7-Step Zero-Trust Allow-List** and constant-time HMAC-SHA256/Bearer verification.

2. **Tier 2 — Lightweight Secondary Path: Direct PE/Win64 Translation (`wsu run <app.exe>`)**
   - Uses **Wine64 + Winetricks + Linux Kernel `binfmt_misc`** (`MZ` header registration) configured to report a **Windows 11 (`win64`)** environment at `~/.local/share/stormraven-wsu/prefix`.
   - Allows single-binary Windows utilities (`.exe`, `.msi`, `.bat`, `cmd`, `notepad`, `regedit`) to execute directly from the Ubuntu terminal (`wsu run app.exe` or `./app.exe`) without booting the full KVM cell.

## 2. CLI & Bifrost Gateway Surface
- **CLI (`/usr/local/bin/stormraven-wsu` & `/usr/local/bin/wsu`):**
  - `stormraven wsu status` / `wsu status` — Reports JSON status of both the KVM Sovereign Cell and the Wine64/binfmt_misc layer.
  - `stormraven wsu init` / `wsu init` — Installs/initializes `wine64`, `winetricks`, `freerdp2-x11`, and `binfmt_misc` `DOSWin` registration.
  - `stormraven wsu run <target.exe>` / `wsu run <target.exe>` — Runs a Windows `.exe`, `.msi`, or `.bat` binary directly.
  - `stormraven wsu cell <start|stop|status>` — Controls the RavenNest Windows 11 KVM Sovereign Cell.
- **Bifrost Gateway Intents (`Ipc/BifrostGateway.cs`):**
  - `wsu_status` / `odin_wsu_status` — Executes `stormraven-wsu status` via `ExecDistroCli` (`ArgumentList`, `UseShellExecute = false`).
  - `wsu_cell_status` — Executes `stormraven-wsu cell status` via `ExecDistroCli`.
