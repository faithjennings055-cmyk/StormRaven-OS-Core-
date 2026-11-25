# StormRaven Companion (iOS)

Native SwiftUI remote-control app for the **StormRaven OS kernel**. It connects to the
kernel's **Bifrost gateway** (`Ipc/BifrostGateway.cs`) — an HTTP + WebSocket bridge the
kernel exposes alongside its classic named-pipe IPC — and gives you kernel health,
Edge-tabs telemetry, decision-engine output, and a live event console, all from your
phone.

```
┌─────────────────────┐   HTTP  /health /state /tabs /decisions /commands
│  StormRaven iOS app │ ◄───────────────────────────────────────────────┐
│  (SwiftUI, dark)    │   WS /ws  hello · health.tick · decision ·      │
└─────────────────────┘            signal · command.accepted             │
                                                                        │
                                                   ┌────────────────────┴──────────┐
                                                   │  Bifrost Gateway (:8787)      │
                                                   │  Ipc/BifrostGateway.cs        │
                                                   │  ─────────────────────────    │
                                                   │  EdgeTabsProvider → Signal    │
                                                   │  DecisionEngine  → Decisions  │
                                                   │  StormRavenDb    → SQLite     │
                                                   │  (named-pipe PipeServer still │
                                                   │   available for local IPC)    │
                                                   └───────────────────────────────┘
```

## Opening the project

Open `StormRavenCompanion.xcodeproj` in Xcode 16+ (folder-synced project — every Swift
file under `StormRavenCompanion/` is picked up automatically). Deployment target is
iOS 17. No external dependencies.

## Screens

| Tab | What it does |
|---|---|
| **Status** | Kernel health (uptime, signal count, open tabs, connected clients), normalized state chips (focus / activity / cpu / network / power), provider status, quick commands (ping, sync, evaluate). |
| **Tabs** | Live list from the Edge-tabs provider (`sr.signal.edge.tabs.v1`); current tab highlighted; per-tab **Focus** / **Close** commands. |
| **Decisions** | Decision-engine history from `/decisions`, live decisions pushed over `/ws`, and a **Run engine** trigger (`POST /commands {"intent":"evaluate"}`). |
| **Console** | Live event log of everything arriving on the WebSocket stream plus command acks. |
| **Link** | Kernel host/port/TLS settings (persisted), connect/disconnect, and the full route map for debugging. |

## How it talks to the kernel

Every REST response is an envelope `{ "ok": true, "data": … }` / `{ "ok": false, "error": { "code", "message" } }`,
camelCase on the wire, ISO-8601 dates. The WebSocket greeting (`hello`) carries current
health/state/tabs so the UI can paint immediately; afterwards the kernel pushes
`health.tick` every 15 s, plus `decision`, `signal`, and `command.accepted` events as
they happen. The app pings the socket every 20 s to keep it alive.

### Endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `/health` | kernel status, uptime, counters, providers |
| GET | `/state` | last `NormalizedState` snapshot |
| GET | `/tabs` | Edge-tabs provider output |
| POST | `/tabs` | ingest a tab array → normalize → evaluate |
| GET | `/decisions` | recent decision-engine output (newest last) |
| POST | `/decisions/evaluate` | evaluate a posted `NormalizedState` |
| POST | `/commands` | `{"intent": "…", "target": "…"}` — allow-listed: `ping`, `get_state`, `get_tabs`, `evaluate`, `focus_tab`, `close_tab` |
| WS | `/ws` | live event stream |

## Running the kernel side

On the Windows machine (or any .NET 8 host):

```powershell
dotnet run --project StormRaven.Kernel.csproj        # gateway listens on :8787
# STORMRAVEN_GATEWAY_PORT=9000 to change the port, STORMRAVEN_NO_GATEWAY=1 to disable
```

Then set the Windows host's IP in the app's **Link** tab (default `192.168.1.50:8787`).
Both devices must be on the same network, or use a tunnel (e.g. Tailscale) for remote.

> Note: `POST /commands` is deliberately allow-listed. Unknown intents are **rejected**,
> and `shutdown_kernel` is never permitted over the mobile bridge.
