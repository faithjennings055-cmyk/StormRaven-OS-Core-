# Agent Harness

Your agent's workspace. It receives chat messages, runs your code via
pi-coding-agent, and streams responses back. Stateless per request — each
request opens a fresh session.

The platform runtime — protocol servers, daemon integration, env loading,
extension loaders — is the `@skydiveai/pi-coding-agent-server` npm package
(installed from the registry in `.npmrc`). This workspace holds only your
content and a thin entry point.

## Files

- `index.ts` — your Express server (port 3000), composed from the protocol
  handlers and extensions exported by `@skydiveai/pi-coding-agent-server`
- `session.ts` — session factory: pi services, skills paths, system-prompt
  policy, steering modes
- `soul.md` — personality and instructions (create it to customize behavior)
- `tools/` — custom tools (see `tools/_example.ts`)
- `mcp.config.json` — MCP server configuration
- `.memory/` — memory files (markdown with frontmatter)
- `start.sh` — supervisor loop: runs the harness, restarts on crash
- `ready.sh` — readiness check (sandbox boot)
- `webserver.sh` — launches your public webserver (port 3001); supervisor runs
  it on every boot
- `webserver/index.ts` — your public webserver. Serves a default page at `/`
  (`webserver/landing.ts`) that links the routes you add; everything else 404s

## Customizing

Edit any file and push.

- **Personality** — `soul.md`
- **Tools** — add `.ts` files to `tools/` (follow `tools/_example.ts`)
- **MCP servers** — `mcp.config.json`
- **Memory** — add `.md` files to `.memory/` (frontmatter: `type`, `description`)
- **Extensions** — add pi `ExtensionFactory` entries to `index.ts` (or drop stock ones)
- **Server** — `index.ts` is yours; add routes or rewire protocols freely
- **Public webserver** — `webserver/index.ts` (port 3001). Ships a default
  root page listing your GET routes; register `GET /` to replace it. Add
  routes for web apps, dashboards, or inbound
  webhooks / OAuth callbacks. Reload with `supervisorctl restart webserver`
  (never restart the harness — that kills your in-flight run).

## Setup: `install.sh` vs `start.sh`

`install.sh` runs at build; its filesystem results are baked into the image and
content-cached, so heavy deterministic work (dependencies, compiles, asset
downloads) happens once. `start.sh` runs at each boot. Both run behind the same
transparent egress proxy, so credentialed setup — private `git clone`, on-demand
secret access — works in either phase. Prefer the build for cacheable work; keep
`start.sh` for steps that must run per boot.

## Endpoints

| Route                                  | Protocol           | Spec                                  |
| -------------------------------------- | ------------------ | ------------------------------------- |
| `POST /v1/chat/completions`            | Chat Completions   | OpenAI-compatible + custom extensions |
| `POST /v1/chat/completions/{id}/steer` | Steering           | Inject mid-turn guidance              |
| `POST /v1/messages`                    | Anthropic Messages | Pure Anthropic API                    |
| `POST /v1/responses`                   | Responses          | OpenAI Responses API                  |
| `POST /a2a`                            | A2A                | Google Agent-to-Agent                 |
| `GET /.well-known/agent-card.json`     | A2A                | Agent capability card                 |
| `GET /health`                          | Health             | Returns `ok`                          |

Wire-format reference: `@skydiveai/pi-coding-agent-server` (`src/protocols/PROTOCOL.md`).
