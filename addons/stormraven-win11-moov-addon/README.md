# StormRaven OS: Infinity Protocol v3.9.0 — Windows 11 Edition + Moov AI Addon Package

This addon package upgrades any StormRaven OS or Ubuntu 24.04/26.04 or Windows 11 machine with:
1. **StormRaven OS — Windows 11 Edition Command Center (`stormraven-shell-window`) & Cryo-Glass Web OS (`?os=win11`)**
2. **Moov AI Financial & Mobile Check Deposit Engine (`stormraven-moov` / `moov-ai` v4.2)**:
   - Spec-compliant 94-character NACHA `.ach` Same-Day ACH file generator with ABA Mod-10 routing verification
   - X9.37 / Check 21 `.x937` Image Cash Letter (ICL) Mobile Check Deposit engine
   - Shared multi-user SQLite ledger (`/var/lib/stormraven/moov/moov_ledger.db`)
   - Live Moov.io v2025.07 REST API integration (`stormraven-moov configure`)
3. **Official StormRaven OS Showcase Website (`showcase.html`)**

## 1-Command Install (Ubuntu / StormRaven OS)
```bash
curl -fsSL https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/install-win11.sh | sudo bash
```

## 1-Command Install (Native Microsoft Windows 11 PowerShell)
```powershell
irm https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/install-win11.ps1 | iex
```
