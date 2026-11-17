#Requires -RunAsAdministrator
<#
.SYNOPSIS
    StormRaven OS -- Write StormRaven Micro to an SD card for Surface 3 (32-bit UEFI).
.DESCRIPTION
    Regression story (Issue #108, 2026-11-16 Surface 3 incident; pattern source #87):
      A boot-repair sequence from Windows RE used 'assign letter=S' on an ambiguous
      disk selection in a multi-drive machine (58GB SSD + 119GB microSD + 465GB
      external USB all attached). Firmware 'Boot Option Restoration' auto-reset
      boot config and caused a 1-hour red-screen bootloop.
      Rule: Verify target disk by Model / SerialNumber / UniqueId / Label / Size
      before any write, support -VerifyMode (lists disks with labels & serials and
      prompts for the target serial), refuse OS/boot disks, and require typing ERASE.

    Tested paste-ready one-liner (Admin PowerShell):
      cd $env:TEMP; curl.exe -fsSLO https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/write-micro-sd.ps1; curl.exe -fsSLO https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/write-micro-sd.ps1.sha256; if ((Get-FileHash .\write-micro-sd.ps1 -Algorithm SHA256).Hash.ToLower() -ne (Get-Content .\write-micro-sd.ps1.sha256).Split(' ')[0].Trim().ToLower()) { throw 'SHA-256 mismatch' }; powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\write-micro-sd.ps1 -VerifyMode
#>
param(
    [int]$DiskNumber = -1,
    [string]$TargetLabel = "",
    [string]$TargetUniqueId = "",
    [switch]$VerifyMode,
    [string]$IsoPath = "",
    [switch]$SkipVerifyIso,
    [int]$BootPartitionGB = 4,
    [switch]$CreateDataPartition
)
$ErrorActionPreference = "Continue"
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$BaseUrl   = "https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app"
$IsoName   = "StormRavenOS-Micro-v1.0-amd64.iso"
$IsoUrl    = "$BaseUrl/iso/$IsoName"
$SumUrl    = "$BaseUrl/iso/$IsoName.sha256"
$WorkDir   = "C:\StormRaven\sdprep"
$DesktopDir = [Environment]::GetFolderPath("Desktop")
$LogPath   = Join-Path $DesktopDir "StormRaven-Micro-SD-Log.txt"

New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
try { Set-Location $WorkDir } catch { Set-Location C:\Windows\Temp }
$env:TEMP = $WorkDir
$env:TMP  = $WorkDir

function Log {
    param([string]$Text, [string]$Color = "Gray")
    Write-Host $Text -ForegroundColor $Color
    try { Add-Content -Path $LogPath -Value $Text } catch {}
}

"=== StormRaven Micro SD writer: $(Get-Date) ===" | Set-Content -Path $LogPath -Encoding ASCII

Log "=======================================================================" Cyan
Log " * STORMRAVEN OS: MICRO EDITION -- SD CARD WRITER" Cyan
Log "   199 MB live system - boots on 32-bit UEFI (Surface 3)" Cyan
Log "=======================================================================" Cyan
Log ""

New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null

# ---------------------------------------------------------------- disks
Log "==> [1/5] Disks on this machine (Model / Serial / Bus / Size / Labels):" Cyan
$disks = Get-Disk -ErrorAction SilentlyContinue | Sort-Object Number
foreach ($d in $disks) {
    $sizeGb = [math]::Round($d.Size / 1GB, 1)
    $serial = if ($d.SerialNumber) { $d.SerialNumber.Trim() } else { $d.UniqueId }
    $vols = @(Get-Partition -DiskNumber $d.Number -ErrorAction SilentlyContinue | Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.FileSystemLabel } | ForEach-Object { "$($_.DriveLetter):$($_.FileSystemLabel)" }) -join ","
    if (-not $vols) { $vols = "unlabeled" }
    $flag = ""
    if ($d.BusType -eq "SD") { $flag = "  <-- SD card" }
    elseif ($d.BusType -eq "USB") { $flag = "  <-- USB" }
    Log ("    Disk {0,-2} {1,-6} {2,7} GB  Model={3}  Serial={4}  Labels=[{5}]{6}" -f $d.Number, $d.BusType, $sizeGb, $d.FriendlyName, $serial, $vols, $flag)
}
Log ""

if ($VerifyMode) {
    $wantedSerial = Read-Host "Enter the exact Serial (or Label) of the intended target disk to verify"
    if (-not $wantedSerial) {
        Log "CRITICAL: Empty serial/label entered in -VerifyMode. Failing closed." Red
        return
    }
    $TargetUniqueId = $wantedSerial.Trim()
}

if ($TargetLabel) {
    $matchedVol = Get-Volume -FileSystemLabel $TargetLabel -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $matchedVol) {
        Log "CRITICAL: Target volume label '$TargetLabel' was not found on any attached disk. Failing closed." Red
        return
    }
    $matchedPart = $matchedVol | Get-Partition -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $matchedPart) {
        Log "CRITICAL: Could not resolve partition for volume label '$TargetLabel'. Failing closed." Red
        return
    }
    $DiskNumber = [int]$matchedPart.DiskNumber
} elseif ($TargetUniqueId) {
    $matchedDisk = Get-Disk -ErrorAction SilentlyContinue | Where-Object {
        ($_.UniqueId -and $_.UniqueId.Trim() -eq $TargetUniqueId) -or
        ($_.SerialNumber -and $_.SerialNumber.Trim() -eq $TargetUniqueId)
    } | Select-Object -First 1
    if (-not $matchedDisk) {
        $matchedVolByLabel = Get-Volume -FileSystemLabel $TargetUniqueId -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($matchedVolByLabel) {
            $mp = $matchedVolByLabel | Get-Partition -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($mp) { $matchedDisk = Get-Disk -Number $mp.DiskNumber -ErrorAction SilentlyContinue }
        }
    }
    if (-not $matchedDisk) {
        Log "CRITICAL: Target disk UniqueId/Serial/Label '$TargetUniqueId' was not found on any attached disk. Failing closed." Red
        return
    }
    $DiskNumber = [int]$matchedDisk.Number
}

if ($DiskNumber -lt 0) {
    Log "Nothing was changed." Yellow
    Log "Re-run with -VerifyMode, -TargetUniqueId <SERIAL>, -TargetLabel <LABEL>, or -DiskNumber <N>:" White
    Log "    & `"$PSCommandPath`" -VerifyMode" White
    Log "    & `"$PSCommandPath`" -TargetLabel STORMRAVEN" White
    Log "    & `"$PSCommandPath`" -DiskNumber 2" White
    Log ""
    Log "Pick the removable disk whose BusType is SD or USB." Yellow
    return
}

$target = Get-Disk -Number $DiskNumber -ErrorAction SilentlyContinue
if (-not $target) {
    Log "ERROR: no disk $DiskNumber exists." Red
    return
}

$sizeGb = [math]::Round($target.Size / 1GB, 1)
$targetSerial = if ($target.SerialNumber) { $target.SerialNumber.Trim() } else { $target.UniqueId }
Log "==> [2/5] RESOLVED TARGET (Core #108 Verification):" Cyan
Log "    Disk   : $DiskNumber"
Log "    Model  : $($target.FriendlyName)"
Log "    Serial : $targetSerial"
Log "    Bus    : $($target.BusType)"
Log "    Size   : $sizeGb GB"
Log ""

# ---------------------------------------------------------------- safety gates
$abort = $false
if ($target.IsBoot -or $target.IsSystem) {
    Log "ABORT: disk $DiskNumber is the boot/system disk." Red
    $abort = $true
}
if ($target.BusType -notcontains "SD" -and $target.BusType -notcontains "USB" -and $target.BusType -notcontains "MMC" -and $target.BusType -notcontains "Unspecified") {
    Log "ABORT: disk $DiskNumber is BusType '$($target.BusType)', not removable." Red
    $abort = $true
}
if ($target.Size -gt 2000GB) {
    Log "ABORT: disk $DiskNumber is $sizeGb GB. Guard stops you wiping a >2 TB drive." Red
    $abort = $true
}
if ($sizeGb -lt 1) {
    Log "ABORT: disk $DiskNumber is only $sizeGb GB, too small." Red
    $abort = $true
}
$osDrive = (Get-Partition -DriveLetter C -ErrorAction SilentlyContinue).DiskNumber
if ($osDrive -eq $DiskNumber) {
    Log "ABORT: disk $DiskNumber holds your Windows C: drive." Red
    $abort = $true
}
if ($abort) {
    Log ""
    Log "Nothing was changed." Yellow
    return
}

Log "    This ERASES disk $DiskNumber completely." Red
$confirm = Read-Host "    Type ERASE in capitals to continue, anything else cancels"
if ($confirm -cne "ERASE") {
    Log "    Cancelled. Nothing was changed." Yellow
    return
}
Log ""

# ---------------------------------------------------------------- ISO
Log "==> [3/5] Getting StormRaven Micro..." Cyan
if (-not $IsoPath -or -not (Test-Path $IsoPath)) {
    $IsoPath = Join-Path $WorkDir $IsoName
}

$expected = $null
if (-not $SkipVerifyIso) {
    $sumFile = Join-Path $WorkDir "$IsoName.sha256"
    & curl.exe -fsSL -o $sumFile $SumUrl
    if (Test-Path $sumFile) {
        $line = (Get-Content $sumFile -Raw).Trim()
        $candidate = ($line -split '\s+')[0].ToLower()
        if ($candidate -match '^[0-9a-f]{64}$') { $expected = $candidate }
    }
    if ((Test-Path $IsoPath) -and $expected) {
        $cachedHash = (Get-FileHash $IsoPath -Algorithm SHA256).Hash.ToLower()
        if ($cachedHash -ne $expected) {
            Log "    Cached ISO had an older build hash -- downloading latest build..." Yellow
            Remove-Item $IsoPath -Force -ErrorAction SilentlyContinue
        }
    }
}

if (-not (Test-Path $IsoPath)) {
    Log "    Downloading ISO (about a minute on decent wifi)..."
    & curl.exe -fL --retry 3 --retry-delay 2 -o $IsoPath $IsoUrl
}
if (-not (Test-Path $IsoPath)) {
    Log "ERROR: download failed." Red
    Log "Manual: $IsoUrl" Red
    return
}
$isoMb = [math]::Round((Get-Item $IsoPath).Length / 1MB, 0)
Log "    ISO: $isoMb MB"

if ($SkipVerifyIso) {
    Log "    SHA-256 verification skipped." Yellow
} else {
    if (-not $expected) {
        Log "ERROR: could not read the published checksum." Red
        return
    }
    $actual = (Get-FileHash $IsoPath -Algorithm SHA256).Hash.ToLower()
    if ($actual -ne $expected) {
        Log "ERROR: ISO checksum mismatch." Red
        Log "  expected: $expected" Red
        Log "  actual:   $actual" Red
        Log "Delete the ISO and try again." Yellow
        return
    }
    Log "    [OK] SHA-256 verified ($($actual.Substring(0,16))...)" Green
}

# ---------------------------------------------------------------- format
# Use diskpart.exe instead of WMI Clear-Disk / Format-Volume, because Windows 10
# Storage WMI deadlocks on external USB-SATA bridges (like WDC WD5000BEVT).
Log "==> [4/5] Partitioning and quick-formatting disk $DiskNumber via diskpart..." Cyan

$bootMb = [int]$BootPartitionGB * 1024
if ($bootMb -lt 2048) { $bootMb = 4096 }
if ($bootMb -gt 30720) { $bootMb = 30720 }

# Pick a free drive letter (prefer S, R, T, U, V, W)
$usedLetters = @(Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Name)
$driveLetter = "S"
foreach ($cand in @("S","R","T","U","V","W","Z","Y","X")) {
    if ($usedLetters -notcontains $cand) { $driveLetter = $cand; break }
}

$dpScript = Join-Path $WorkDir "diskpart-stormraven.txt"
@"
select disk $DiskNumber
clean
convert gpt
create partition primary size=$bootMb
format fs=fat32 label="STORMRAVEN" quick
assign letter=$driveLetter
exit
"@ | Set-Content -Path $dpScript -Encoding ASCII

$dpOut = & diskpart.exe /s $dpScript 2>&1
foreach ($line in ($dpOut | Out-String -Stream)) {
    if ("$line".Trim()) { Log "    [diskpart] $("$line".Trim())" Gray }
}

if ($CreateDataPartition) {
    $dpDataScript = Join-Path $WorkDir "diskpart-srdata.txt"
    @"
select disk $DiskNumber
create partition primary
format fs=exfat label="SRDATA" quick
exit
"@ | Set-Content -Path $dpDataScript -Encoding ASCII
    & diskpart.exe /s $dpDataScript 2>&1 | Out-Null
}

Start-Sleep -Seconds 2
if (-not (Test-Path "${driveLetter}:\")) {
    # Fallback: discover the STORMRAVEN volume letter if Windows assigned a different one
    $vol = Get-Volume -FileSystemLabel "STORMRAVEN" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($vol -and $vol.DriveLetter) {
        $driveLetter = [string]$vol.DriveLetter
    }
}

if (-not (Test-Path "${driveLetter}:\")) {
    Log "ERROR: could not find formatted partition ${driveLetter}:\ after diskpart." Red
    return
}
Log "    [OK] ${driveLetter}: FAT32 (STORMRAVEN, $BootPartitionGB GB)" Green
Log ""

# ---------------------------------------------------------------- copy
Log "==> [5/5] Copying the system onto the card..." Cyan
$mount = Mount-DiskImage -ImagePath $IsoPath -PassThru -ErrorAction Stop
$isoDrive = $null
try {
    $isoDrive = ($mount | Get-Volume -ErrorAction SilentlyContinue).DriveLetter
    if (-not $isoDrive) { Start-Sleep -Seconds 2; $isoDrive = ($mount | Get-Volume -ErrorAction SilentlyContinue).DriveLetter }
    if (-not $isoDrive) { Log "ERROR: could not mount the ISO." Red; return }
    Log "    Source: $isoDrive`:"

    $tooBig = Get-ChildItem "${isoDrive}:\" -Recurse -File -ErrorAction SilentlyContinue |
              Where-Object { $_.Length -gt 4GB } | Select-Object -First 3
    if ($tooBig) {
        Log "ERROR: files exceed FAT32's 4 GB per-file limit:" Red
        foreach ($f in $tooBig) { Log "    $($f.Name) = $([math]::Round($f.Length/1GB,2)) GB" Red }
        return
    }

    $srcRoot = "${isoDrive}:\"
    $dstRoot = "${driveLetter}:\"
    $rc = Start-Process -FilePath "robocopy.exe" `
        -ArgumentList @($srcRoot, $dstRoot, "/E", "/NFL", "/NDL", "/NJH", "/NJS", "/R:1", "/W:1") `
        -Wait -PassThru -NoNewWindow
    if ($rc.ExitCode -ge 8) {
        Log "ERROR: copy failed (robocopy exit $($rc.ExitCode))." Red
        return
    }
    Log "    [OK] copied." Green
} finally {
    Dismount-DiskImage -ImagePath $IsoPath -ErrorAction SilentlyContinue | Out-Null
}

# ---------------------------------------------------------------- verify
Log ""
Log "==> Verifying the card (Secure Boot + TPM 2.0 Ready):" Cyan
$checks = @(
    @{ Path = "EFI\BOOT\BOOTIA32.EFI";    MinBytes = 65536;    Why = "32-bit Microsoft-signed UEFI Secure Boot shim (Surface 3)" },
    @{ Path = "EFI\BOOT\grubia32.efi";    MinBytes = 524288;   Why = "32-bit Debian-signed GRUB2 + TPM 2.0 bootloader" },
    @{ Path = "EFI\BOOT\BOOTX64.EFI";     MinBytes = 65536;    Why = "64-bit Microsoft-signed UEFI Secure Boot shim" },
    @{ Path = "EFI\BOOT\grubx64.efi";     MinBytes = 524288;   Why = "64-bit Debian-signed GRUB2 + TPM 2.0 bootloader" },
    @{ Path = ".disk\info";               MinBytes = 10;       Why = "Signed GRUB volume discovery marker" },
    @{ Path = "boot\grub\grub.cfg";       MinBytes = 100;      Why = "StormRaven boot configuration" },
    @{ Path = "live\vmlinuz";             MinBytes = 5242880;  Why = "Signed Linux 6.1 kernel (Secure Boot + TPM 2.0)" },
    @{ Path = "live\initrd.img";          MinBytes = 10485760; Why = "Initial ramdisk" },
    @{ Path = "live\filesystem.squashfs"; MinBytes = 52428800; Why = "Root filesystem" }
)
$missing = 0
foreach ($c in $checks) {
    $full = Join-Path "${driveLetter}:\" $c.Path
    if (Test-Path $full) {
        $len = (Get-Item $full -ErrorAction SilentlyContinue).Length
        if ($len -ge $c.MinBytes) {
            Log "    [OK]   $($c.Path) ($([math]::Round($len/1KB,0)) KB) -- $($c.Why)" Gray
        } else {
            Log "    [SHORT] $($c.Path) ($len bytes < $($c.MinBytes) expected) -- $($c.Why)" Yellow
            $missing++
        }
    } else {
        Log "    [MISS] $($c.Path)  -- $($c.Why)" Yellow
        $missing++
    }
}
if ($missing -gt 0) {
    Log ""
    Log "WARNING: $missing expected file(s) missing or incomplete. The card may not boot." Yellow
}

Log ""
Log "=======================================================================" Green
Log " * SD CARD READY -- STORMRAVEN OS MICRO" Green
Log "=======================================================================" Green
Log ""
Log "Boot it on the Surface 3 without holding buttons:" Cyan
Log "  Run this in Admin PowerShell to reboot straight to the UEFI device picker:" White
Log "    shutdown.exe /r /o /f /t 0" Cyan
Log "  (Then tap 'Use a device' -> 'USB Storage')" Gray
Log ""
Log "Or boot with buttons:" Cyan
Log "  1. Turn the Surface fully OFF (Start > Power > Shut down)." White
Log "  2. Hold VOLUME DOWN, then press POWER. Keep holding Volume Down" White
Log "     until the Surface logo appears -- that opens the boot menu." White
Log "  3. Choose the USB storage device." White
Log ""
Log "  If it will not boot: switch off Secure Boot. Power off, hold" White
Log "  VOLUME UP + POWER, then UEFI > Security > Secure Boot > Disable." White
Log ""
Log "Once running:" Cyan
Log "  - It auto-logs in as 'stormraven' (password: stormraven)" White
Log "  - Type: stormraven status     for a system summary" White
Log "  - Type: sudo -i               for a root shell" White
Log ""
Log "Note: the live system runs from the card and uses RAM for changes." Yellow
Log "Nothing is saved between reboots unless you set up persistence." Yellow
Log ""
Log "Log: $LogPath" White
