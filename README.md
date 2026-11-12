# StormRaven OS Infinity Protocol (Ubuntu 24.04 LTS "Noble Numbat" & Mobile Edition)

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

## Architectural Bedrock (Infinity Protocol)

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
\n## Durable Build Artifact Mirror & Provenance Recovery (#95)

All release artifacts and their `.sha256` sidecars follow a dual-layer durability and provenance standard:

1. **Automatic Post-Build Mirror (`~/Documents/`):**
   - Both `distro/build-ubuntu-iso.sh` and `distro/build-win11-iso.sh` automatically mirror the built ISO and its `.sha256` sidecar to persistent storage (`${STORMRAVEN_ARTIFACT_MIRROR_DIR:-~/Documents}`) immediately after packaging.
   - On cold boot, the gateway (`webserver.sh`) hydrates `/tmp/iso/` asynchronously in the background and falls back directly to `~/Documents/<filename>` so downloads never block or 404.
2. **In-Repo Cryptographic Provenance (`distro/PROVENANCE.json`):**
   - `distro/PROVENANCE.json` records the authoritative SHA-256 digests and builder recipes for `StormRavenOS-ubuntu-24.04-amd64.iso` / `StormRavenOS-Infinity-Protocol-v3.9.0-amd64.iso`, `StormRavenOS-Win11-Ymir-v3.9.0-amd64.iso`, `StormRavenOS-Win11-Full-v3.9.0-x64.zip`, `stormraven-os_3.9.0_amd64.deb`, and `stormraven-os_3.9.0_amd64.snap`.
   - **Recovery Procedure:** Restore from the persistent `~/Documents/` mirror if present (`sha256sum -c <artifact>.sha256`); otherwise run `sudo bash distro/build-ubuntu-iso.sh` or `sudo bash distro/build-win11-iso.sh` and verify the resulting digest against `distro/PROVENANCE.json`.

## Current Milestone: Bedrock Complete\n- Ymir Ring 0 Core: IMPLEMENTED\n- Buddy/SLAB Allocator: LIVE\n- Zero-Trust Gatekeeper: LIVE\n- Neural-Symbolic Scheduler: LIVE\n- Phase: Transitioning to Visuals & GUI Layer
