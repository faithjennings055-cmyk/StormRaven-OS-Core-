# Storm Raven OS: Niðavellir Edition — Alfheim UI

The **Alfheim UI** is the frontend dashboard for Storm Raven OS, built with Next.js, React, Tailwind, and shadcn/ui. It links to the Bifröst WebSocket gateway and renders the Pantheon of autonomous daemons that make up the system.

This README is the canonical entry point for the UI: it defines the architectural vision, the hybrid-kernel paradigm, and the mythological taxonomy that governs the system.

## Overview

Storm Raven OS is a hybrid-kernel operating environment designed for high-assurance forensic hygiene, modular security, and autonomous system governance. It combines the bare-metal control of a hardened Linux kernel with capability-based isolation (WebAssembly / WASI) and C# system services.

## Architectural Paradigm: "Starlight Core"

Storm Raven OS avoids a conventional monolithic structure. It uses a **Hybrid Microkernel Matrix** that delegates specialized intelligence to an isolated Pantheon of autonomous daemons.

### The Pantheon (Modular Deities)

Operational logic is distributed across specialized modules, each mapped to a Norse figure:

- **Odin** (Orchestrator) — central logic flow and multi-module coordination
- **Heimdall** (Security) — heuristic command sanitization and threat blacklisting
- **Thor** (Executioner) — native command execution and strike agent
- **Loki** (Memory) — persistent JSON logging and session history
- **Bifröst** (Gateway) — structured API/IPC bridge for cross-platform mapping
- **Jörmungandr** (Sentinel) — system monitoring and network encapsulation

## Forensic Posture (Yggdrasil VFS)

Data residency is compartmentalized to enforce strict forensic footprints:

- **Alfheim** — persistent source code (ReFS/NTFS)
- **Midgard** — volatile RAM-disk execution (zero-footprint)
- **Niflheim** — encrypted vault storage for sensitive Mjolnir soul-binds
- **Helheim** — redirected shadow logs for forensic evaporation

## Security Mandate

- **Zero-Trust Perimeter** — all API requests authenticated via JWT and time-gated TOTP 2FA
- **DDoS Mitigation** — Redis-based rate limiting integrated into the Múspellheimr Core
- **Immutability** — core daemons protected via kernel-level immutable file attributes (`chattr +i` on Linux) and systemd service hardening

## This Repository (Alfheim UI)

The Next.js app lives here:

- `app/` — routes, layout, and API handlers (including `better-auth` under `app/api/auth`)
- `components/` — shared UI components (shadcn/ui)
- `lib/` — utilities and client helpers

### Prerequisites

- Node.js 18+ and `pnpm`

### Quick Start

```bash
# Install dependencies
pnpm install

# Run the dev server
pnpm dev

# Build for production
pnpm build && pnpm start
```

The dashboard connects to the Bifröst WebSocket gateway exposed by `StormRaven.Kernel`.

## Licensing & Compliance

This software is engineered for ethical hacking, authorized security auditing, and academic research. Use of these tools for unauthorized access is a violation of law. The architecture assumes no liability for misuse.
