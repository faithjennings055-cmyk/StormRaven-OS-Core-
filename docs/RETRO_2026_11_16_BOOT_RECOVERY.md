# Post-Incident Retrospective: 2026-11-16 Boot & Target Verification Hardening (#107)

## Summary of Incident (2026-11-16 Night)
1. **Mid-flight upgrade interruption on HP:** An upgrade run on the HP system was terminated mid-flight, leaving boot/system state partially updated and triggering a bootloop.
2. **Drive-letter ambiguity during recovery (`S:`):** Subsequent recovery attempts used drive-letter-relative commands (`S:`) on Windows, creating target ambiguity when multiple removable media (119 GB microSD card vs. 465.8 GB external USB drive) were attached.
3. **Surface 3 firmware state:** A firmware reset / Secure Boot interaction placed the Surface 3 into a red-screen UEFI state while the HP was simultaneously down.
4. **Data integrity:** Both internal drives (Windows 10 on the Surface 3 eMMC and StormRaven OS on the HP SSD) were verified intact — zero user data was lost.

## Root Cause Analysis
- **Unverified target assumptions:** Upgrade and recovery scripts that assume `/` (even on a live overlay) or rely on volatile Windows drive letters (`E:`, `S:`) instead of verifying partition `LABEL` or `UUID` can act on the wrong filesystem or fail to persist across reboot.
- **Non-atomic binary writes:** Streaming `curl ... -o /usr/local/bin/<tool>` directly into place leaves a truncated or half-written binary if the process or network drops mid-transfer.
- **WMI `Clear-Disk` hangs on USB-SATA bridges:** Windows Storage WMI (`Clear-Disk` / `Format-Volume`) deadlocks on external USB-SATA bridges (such as `WDC WD5000BEVT`), prompting the user to kill the window mid-partition.

## Hardening Standard Enforced (#107)
All upgrade, USB/SD writer, and recovery scripts (`distro/upgrade-hp.sh`, `distro/flash-usb.sh`, `write-infinity-sd.ps1`, `write-micro-sd.ps1`, `make-surface3-usb.sh`, `Make-Surface3-USB.ps1`) now enforce four mandatory invariants:

1. **Resolve by `LABEL` or `UUID` and fail closed:**
   - Linux scripts support `--target-label <LABEL>` and `--target-uuid <UUID>` via `blkid -L` / `blkid -U`, refuse live RAM overlays (`overlay` / `/run/live` / `/run/casper`) unless an installed target is explicitly mounted, and exit `1` with `CRITICAL: ... Failing closed.` when the target is absent.
   - Windows PowerShell writers support `-TargetLabel <LABEL>` and `-TargetUniqueId <ID>`, refuse the Windows boot/system/C: drive, and fail closed when the requested label or unique ID is absent.
2. **Print resolved target and require explicit confirmation before write:**
   - Every script prints the `RESOLVED TARGET:` block (`Device`, `UUID`, `LABEL`, `Mountpoint`/`Size`) and requires an explicit interactive confirmation token (`UPGRADE`, `ERASE`, or `UPDATE-EFI`, or `--confirm-uuid <UUID>`) before touching disk state.
3. **Idempotent, atomic, and resumable execution:**
   - `upgrade-hp.sh` downloads into a temporary staging directory (`mktemp -d`) and uses atomic `mv -f` into `${TARGET_ROOT}/usr/local/bin` only after verifying non-empty download completion, backs up `/boot/grub/grub.cfg` before verification, and runs `stormraven-dualboot grub-verify` at completion.
   - Windows SD/USB writers use `diskpart.exe` (`clean`, `convert gpt`, `format fs=fat32 label="STORMRAVEN" quick`) instead of WMI `Clear-Disk`.
4. **Runbook-friendly single-line step logging:**
   - Destructive steps emit a single `[STEP N/M]` log line per step for rapid photo checkpoint verification.
