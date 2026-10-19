# StormRaven OS (Ubuntu 24.04 LTS "Noble Numbat" & Mobile Edition)

StormRaven OS is a hybrid C# + Python operating environment and Ubuntu 24.04 LTS (`noble`) live distribution with full mobile support across iOS, Android, and Linux mobile devices.

## Mobile & Live Endpoints

- **Live Mobile PWA + Cloud Bifrost Gateway:** [`https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/`](https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/)
  - Open directly in **Safari (iOS)** or **Chrome/Edge (Android)** — connects automatically to the live `StormRaven.Kernel` (`sr.bridge.mobile.v1`) and Odin Python Pantheon with zero setup required.
  - Tap **Share → Add to Home Screen** on iPhone or **Install App** on Android for a full-screen standalone mobile OS interface.
- **1-Command Ubuntu 24.04 LTS Mobile Installer (Android Termux / Linux Mobile):**
  ```bash
  curl -fsSL https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/install-mobile.sh | bash
  ```
  See [`distro/mobile/README.md`](distro/mobile/README.md) for full details.

## Architecture

1. **Ubuntu 24.04 LTS ("Noble Numbat") Live Distro (`distro/`)**
   - Reproducible ISO builder (`distro/build-ubuntu-iso.sh`) using `debootstrap noble`, Ubuntu 6.8 generic kernel, `casper` live boot, and `grub-mkrescue`.
   - Bakes `/opt/stormraven/StormRaven.Kernel` (`stormraven-kernel.service` on port `:8787`), `/opt/stormraven/python/odin.py`, `/opt/stormraven/webapp/`, and `/usr/local/bin/stormraven` into the rootfs.
2. **Native C# Kernel & Bifrost Mobile Bridge (`Ipc/BifrostGateway.cs`, `StormRaven.Kernel.Portable/`)**
   - Deterministic `ContextBus`, `EdgeTabsProvider`, `DecisionEngine`, and SQLite `StormRavenDb`.
   - Exposes REST + WebSocket (`GET /health`, `GET /state`, `GET /tabs`, `POST /tabs`, `GET /decisions`, `POST /decisions/evaluate`, `POST /commands`, `GET /signals`, `WS /ws`).
3. **Odin Python Pantheon (`Python/`, `StormRaven.Python/`, `/opt/stormraven/python/`)**
   - Modules: `Odin` (Leviathan Core v5.0), `Thor` (telemetry & execution), `Freya` (autonomous mind), `Heimdall` (security guard), `Bifrost` (intent translation), `Luci`, `Solomon`, `Heketa`, `Lynn`, `Saga`, `Shadow Log`, `Void Viz`, `Ragnarok`, `Deadman`.
4. **Mobile Applications (`webapp/`, `StormRaven.Mobile/`, `ios/StormRavenCompanion/`, `distro/mobile/`)**
   - `webapp/`: Installable Mobile PWA with Status, Tabs, Decisions, Odin Pantheon, and Console views.
   - `StormRaven.Mobile/`: Cross-platform `.NET 8 MAUI` app (`net8.0-ios;net8.0-android`) running `StormRaven.Kernel.Portable` on-device via `KernelHostedService` + remote Bifrost gateway sync.
   - `ios/StormRavenCompanion/`: Native SwiftUI iOS 17+ companion app supporting LAN HTTP and Cloud HTTPS Bifrost gateways.
