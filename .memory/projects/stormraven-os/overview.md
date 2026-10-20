---
name: stormraven-os
description: Faith's StormRaven OS project — repos, stack, health, and how to work on it. Open when she mentions StormRaven / Stormraven OS.
---

# StormRaven OS (Faith's project)

On 2026-10-20 Faith texted "Work on Stormraven os" (iMessage conv 01a159a5-4091-77d6-b791-5e0fff46a433). No specifics given.

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
- 2026-10-20: README of Alfheim-UI was raw pasted assistant-draft text (started "To begin your GitHub repository...", ended "Would you like me to generate..."). Cleaned into proper Markdown. Draft PR #3: https://github.com/faithjennings055-cmyk/StormRaven-Alfheim-UI-/pull/3 (branch docs/clean-readme). Awaiting her review/merge.

## Note
"Work on Stormraven os" is open-ended. Before big changes, get a specific target from Faith. Reversible work (branches, draft PRs, docs) is fine to just do.
