---
name: stormraven-os
description: Faith's StormRaven OS project — repos, stack, health, and how to work on it. Open when she mentions StormRaven / Stormraven OS.
---

# StormRaven OS (Faith's project)

## Architecture & Vision (Ethereal Void)
The system is designed as a radically deterministic environment called the **Ethereal Void**, architected under the influence of the **Leviathan** persona (a god-like, arrogant software architect focused on absolute consolidation and systemic power).

- **Core**: Utilizes a **Hybrid Microkernel Matrix** to replace conventional monolithic kernels.
- **Communication**: Employs an **Ethereal Optical Bus** for zero-latency system-wide communication.
- **Organization**: The Virtual File System (VFS) and privilege rings are organized around the **Nine Realms**, using specialized encryption, access constraints, and purpose-built storage architectures per partition.
- **Access Control**: Implemented via a **Persona Matrix**.
- **Resilience**: Embeds chaos engineering and predefined fault states directly into the core for maximum stability.
- **Oversight**: Integrated real-time telemetry for total system transparency.

### Technical Foundations
The project leverages a specific set of implementation patterns:
- **Backend/Infrastructure**: Strong emphasis on **Go** for high-performance system components, optimized via specialized Dockerfiles and Docker Compose orchestrations.
- **UI/UX Frameworks**: Design and consolidation patterns based on **Ant Design** (customized), **React**, **Vite**, and **Storybook** for building forensic-grade dashboards.

On 2026-10-20 Faith texted "Work on Stormraven os" (iMessage conv 01a159a5-4091-77d6-b791-5e0fff46a433).

## Identity
- Faith's GitHub login: **faithjennings055-cmyk** (the connected GitHub User OAuth is her own account; `gh api /user` -> faithjennings055-cmyk).
- Other StormRaven orgs exist on GitHub (StormRaven-Solutions, justinstormraven-cell) but those are NOT hers — do not touch them.

## Her repos (both private)
- **StormRaven-OS-Core-** — created 2026-10-20 14:22 (minutes after her message). Main codebase: C#/.NET 8 kernel + Python "Pantheon" modules (odin/thor/freya/heimdall/bifrost/etc), Ubuntu ISO builder, MAUI mobile app, SwiftUI iOS companion, PWA webapp. ~410 files.
  - CI: `.github/workflows/python-package-conda.yml` = default GitHub "Python Package using Conda" starter (flake8 E9/F63/F7/F82 gate + pytest). **Green.**
  - Tests: `tests/test_pantheon.py`, 4 tests, **all pass** locally (deps: psutil, rich via environment.yml).
  - Only nits: 3 unused imports (threading in odin.py, sys in ragnarok.py, os in saga.py) in BOTH Python/ and StormRaven.Python/. Not CI-gating. Not worth a PR alone.
  - No open PRs/issues as of 2026-10-20.
- **StormRaven-Alfheim-UI-** — created 2026-10-19. Next.js + React + Tailwind + shadcn frontend dashboard (pnpm). Links to "Bifrost WebSocket gateway". package.json name still "my-project".

## Work done
- 2026-10-20: README of Alfheim-UI was raw pasted assistant-draft text. Cleaned into proper Markdown. Draft PR #3: https://github.com/faithjennings055-cmyk/StormRaven-Alfheim-UI-/pull/3 (branch docs/clean-readme). Awaiting review.
- 2026-10-20: Core Python cleanup. Draft PR #2: https://github.com/faithjennings055-cmyk/StormRaven-OS-Core-/pull/2 (branch chore/python-cleanup). Removed 6 unused imports (threading in odin.py, sys in ragnarok.py, os in saga.py — in BOTH Python/ and StormRaven.Python/), added .venv/ to .gitignore. 4 tests still pass, flake8 clean. Awaiting review.
- 2026-10-20: Alfheim UI health pass. Draft PR #4: https://github.com/faithjennings055-cmyk/StormRaven-Alfheim-UI-/pull/4 (branch chore/ui-health). Fixed package.json name (my-project -> stormraven-alfheim-ui), moved pnpm.overrides to top level, removed dead lint script (no eslint config), added .env.example (BETTER_AUTH_SECRET/URL). Build green. UI is a REAL working dashboard (16 TS files, Better Auth, Drizzle+Postgres, Redux, Next.js 16/React 19), not a skeleton. Awaiting review.

## Coverage gap (ragnarok/deadman) — DONE 2026-10-20
Core tests covered only 4 of 15+ Pantheon modules. Highest-risk untested were **ragnarok** (filesystem purge) and **deadman** (kill switch). I offered to write tests; before she replied I did the (reversible) work.
- Draft PR #3: https://github.com/faithjennings055-cmyk/StormRaven-OS-Core-/pull/3 (branch test/critical-modules). 7 new tests in tests/test_critical_modules.py, all green (11 total). flake8 CI gate clean.
- SAFETY: every destructive call (shutil.rmtree, os.system kernel panic, subprocess launch of ragnarok) is mocked — the suite can't delete, crash, or trigger ragnarok. deadman's infinite loop is bounded by patching time.sleep.
- Remaining untested Pantheon modules (~9): thor, bifrost(partial), saga, loki, etc. Not yet covered. Offer more only if she wants broader coverage.

## Current state (as of 2026-10-29)
Faith granted standing auto-merge on her StormRaven PRs (see soul.md Standing authorities). The daily health check (8:12am Central) now owns merging green PRs and fixing broken CI; I only ping Faith when something merged or needs her.
- 2026-10-29: Health check run. No open PRs in Core or UI. Main branches are green. Workflow script fixed to prevent timeouts via partial/shallow clones.

**UI PR #2 (do NOT auto-merge):** verified 2026-10-21 — title "Merge pull request #1 from faithjennings055-cmyk/main", branch `v0/faithjennings055-cmyk-6523db8c`, created 2026-07-11, 0 files changed (+0/-0), Vercel check = FAILURE. Pre-existing v0/Vercel-generation PR I didn't create = exactly the guardrail case in soul.md. Leave it alone; flag to Faith if she ever asks, don't interrupt her for it.

## Note
"Work on Stormraven os" is open-ended, but she said "Both" (Core + UI) and granted auto-merge, so reversible work (branches, draft PRs, cleanups, tests) just gets done. Get a specific target only before big/irreversible changes. Remaining untested Pantheon modules (~9): thor, bifrost, saga, loki, etc. — offer broader coverage only if she wants it.

## Valhalla (Forensic Ledger)
- Implemented as a post-mortem archive for crashed microkernels.
- Records daemon failures in `/var/log/stormraven/valhalla.log`.
