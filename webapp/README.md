# StormRaven OS — Companion PWA

A mobile-first, installable Progressive Web App companion for the StormRaven OS kernel.
Pure vanilla HTML/CSS/JS — no build step, no dependencies.

## Views

- **Status** — kernel name, health badge, uptime, version, provider count, decision count, per-subsystem health checks (IPC pipe, Edge tabs provider, decision engine, SQLite storage), and a live feed of recent decisions from the DecisionEngine.
- **Tabs** — live list of Edge tabs from the EdgeTabsProvider (`sr.signal.edge.tabs.v1` envelope), with the current/foreground tab highlighted.
- **Console** — command console for the decision engine; sends commands to the kernel and renders structured responses.
- **Settings** — user-configurable kernel gateway URL (persisted in localStorage).

## API contract

Designed against the IPC gateway being added on branch `ios-companion`:

| Method | Path       | Purpose                                  |
|--------|------------|------------------------------------------|
| GET    | `/status`  | Kernel status/health snapshot             |
| GET    | `/tabs`    | Edge tabs (array or `{tabs:[...]}`)       |
| POST   | `/command` | `{ "command": "...", "source": "pwa" }`   |
| WS     | `/events`  | Live events (`status`, `tabs`, `decision`) |

The client is tolerant: it accepts common field aliases (`health`/`healthStatus`, `uptimeSec`/`uptimeSeconds`, `tabs` arrays or envelopes) so the gateway can evolve without breaking the UI. With no gateway reachable, the app degrades gracefully to an offline shell (service worker caches the UI).

## iOS install

Serve over HTTPS, then in Safari: Share → **Add to Home Screen**. The app launches standalone (`apple-mobile-web-app-capable`, black-translucent status bar, safe-area insets, portrait orientation).

## Files

```
webapp/
  index.html      shell + views + settings modal
  style.css       dark OS theme (storm purple #9d50bb)
  app.js          state, REST/WS client, console, routing
  sw.js           offline shell (network-first page, cache-first assets; never caches API traffic)
  manifest.json   installable manifest, maskable icon
  icons/          192/512/maskable/apple-touch icons
```

## Local dev

Any static file server works, e.g. `python3 -m http.server -d webapp 8080`.
The gateway URL can point at any host (e.g. `http://<pc-ip>:5080`).
