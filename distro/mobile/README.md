# StormRaven OS Mobile (Ubuntu 24.04 LTS "Noble Numbat")

StormRaven OS runs end-to-end on mobile devices via three complementary layers:

1. **Instant Mobile PWA + Cloud Bifrost Gateway** (`https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/`)
   - Open directly in **Safari on iOS** or **Chrome/Edge on Android** — zero configuration required.
   - Connects automatically to the live `StormRaven.Kernel` (`sr.bridge.mobile.v1`) and the **Odin Python Pantheon** (`odin.py`, `thor.py`, `freya.py`, `heimdall.py`, `bifrost.py`).
   - Install to your phone's home screen (**Share → Add to Home Screen** on iOS, or **Install App** on Android) for a standalone full-screen OS interface.

2. **Ubuntu 24.04 LTS ("Noble Numbat") On-Device Mobile Environment (Android / Linux Mobile / iOS UTM)**
   - Run the full Ubuntu 24.04 LTS rootfs + StormRaven Python Pantheon (`Odin`, `Thor`, `Freya`, `Heimdall`, `Bifrost`, `Luci`, `Solomon`, `Heketa`, `Lynn`) directly on your phone using **Termux (`proot-distro`)** on Android or any Linux mobile environment (Ubuntu Touch, PostmarketOS, Droidian, Mobian, iSH/UTM on iOS):
   ```bash
   curl -fsSL https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/install-mobile.sh | bash
   ```
   - Once installed, run:
     ```bash
     stormraven status
     stormraven odin
     stormraven odin check_ip
     stormraven odin heimdall_scan
     ```

3. **Native Mobile Apps (`StormRaven.Mobile` .NET 8 MAUI & `ios/StormRavenCompanion` SwiftUI)**
   - **`StormRaven.Mobile/`**: Cross-platform `.NET 8 MAUI` app targeting both `net8.0-ios` and `net8.0-android`. Embeds `StormRaven.Kernel.Portable` (`ContextBus`, `EdgeTabsProvider`, `DecisionEngine`, `StormRavenDb`) inside `KernelHostedService` for on-device kernel execution and remote Bifrost gateway syncing.
   - **`ios/StormRavenCompanion/`**: Native SwiftUI iOS 17+ companion app supporting both LAN (`http://<host>:8787`) and Cloud HTTPS/WSS (`https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app`) Bifrost gateways.
