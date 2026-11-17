#Requires -RunAsAdministrator
<#
.SYNOPSIS
    StormRaven OS -- Write a bootable Linux installer to an SD card for Surface 3 (32-bit UEFI).
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
      cd $env:TEMP; curl.exe -fsSLO https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/make-linux-sd-surface3.ps1; curl.exe -fsSLO https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/make-linux-sd-surface3.ps1.sha256; if ((Get-FileHash .\make-linux-sd-surface3.ps1 -Algorithm SHA256).Hash.ToLower() -ne (Get-Content .\make-linux-sd-surface3.ps1.sha256).Split(' ')[0].Trim().ToLower()) { throw 'SHA-256 mismatch' }; powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\make-linux-sd-surface3.ps1 -VerifyMode
#>
param(
    [int]$DiskNumber = -1,
    [string]$TargetLabel = "",
    [string]$TargetUniqueId = "",
    [switch]$VerifyMode,
    [string]$IsoPath = "",
    [switch]$SkipVerifyIso
)
$ErrorActionPreference = "Continue"
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

$IsoUrl      = "https://cdimage.ubuntu.com/lubuntu/releases/noble/release/lubuntu-24.04.5-desktop-amd64.iso"
$SumsUrl     = "https://cdimage.ubuntu.com/lubuntu/releases/noble/release/SHA256SUMS"
$IsoName     = "lubuntu-24.04.5-desktop-amd64.iso"
$ShimUrl     = "https://github.com/hirotakaster/baytail-bootia32.efi/raw/master/bootia32.efi"
$ShimSha256  = "c4078bdc315cdd974fdb0986b7b73a31539e34bf0644e9d7c64cde925f73300b"
$WorkDir     = "C:\StormRaven\sdprep"
$DesktopDir  = [Environment]::GetFolderPath("Desktop")
$LogPath     = Join-Path $DesktopDir "StormRaven-SD-Writer-Log.txt"

function Log {
    param([string]$Text, [string]$Color = "Gray")
    Write-Host $Text -ForegroundColor $Color
    try { Add-Content -Path $LogPath -Value $Text } catch {}
}

"=== StormRaven SD writer: $(Get-Date) ===" | Set-Content -Path $LogPath -Encoding ASCII

Log "=======================================================================" Cyan
Log " * STORMRAVEN OS -- BOOTABLE LINUX SD CARD FOR SURFACE 3" Cyan
Log "=======================================================================" Cyan
Log ""
Log "Surface 3 uses 32-BIT UEFI. This script installs the bootia32.efi shim so" Yellow
Log "a 64-bit Linux ISO can actually boot on it. Without it, nothing boots." Yellow
Log ""

New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null

# ---------------------------------------------------------------- list disks
Log "==> [1/6] Disks on this machine (Model / Serial / Bus / Size / Labels):" Cyan
$disks = Get-Disk -ErrorAction SilentlyContinue | Sort-Object Number
foreach ($d in $disks) {
    $sizeGb = [math]::Round($d.Size / 1GB, 1)
    $bus = $d.BusType
    $model = $d.FriendlyName
    $serial = if ($d.SerialNumber) { $d.SerialNumber.Trim() } else { $d.UniqueId }
    $vols = @(Get-Partition -DiskNumber $d.Number -ErrorAction SilentlyContinue | Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.FileSystemLabel } | ForEach-Object { "$($_.DriveLetter):$($_.FileSystemLabel)" }) -join ","
    if (-not $vols) { $vols = "unlabeled" }
    $flag = ""
    if ($bus -eq "SD") { $flag = "  <-- likely your SD card" }
    elseif ($bus -eq "USB") { $flag = "  <-- USB" }
    Log ("    Disk {0,-2} {1,-6} {2,7} GB  Model={3}  Serial={4}  Labels=[{5}]{6}" -f $d.Number, $bus, $sizeGb, $model, $serial, $vols, $flag)
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
    Log "Nothing was changed. Re-run with -VerifyMode, -TargetUniqueId <SERIAL>, or -DiskNumber <N>:" Yellow
    Log "    & `"$PSCommandPath`" -VerifyMode" White
    Log "    & `"$PSCommandPath`" -DiskNumber 2" White
    Log ""
    Log "Pick the disk whose size matches your ~119 GB SD card and whose BusType" Yellow
    Log "is SD or USB. Getting this wrong destroys the wrong drive." Yellow
    return
}

$target = Get-Disk -Number $DiskNumber -ErrorAction SilentlyContinue
if (-not $target) {
    Log "ERROR: no disk number $DiskNumber exists." Red
    return
}

$sizeGb = [math]::Round($target.Size / 1GB, 1)
$targetSerial = if ($target.SerialNumber) { $target.SerialNumber.Trim() } else { $target.UniqueId }

Log "==> [2/6] RESOLVED TARGET (Core #108 Verification):" Cyan
Log "    Disk        : $DiskNumber"
Log "    Model       : $($target.FriendlyName)"
Log "    Serial      : $targetSerial"
Log "    Bus         : $($target.BusType)"
Log "    Size        : $sizeGb GB"
Log ""

# Hard safety gates -- never destroy a system or fixed disk
$abort = $false
if ($target.IsBoot -or $target.IsSystem) {
    Log "ABORT: disk $DiskNumber is the boot/system disk." Red
    $abort = $true
}
if ($target.BusType -notcontains "SD" -and $target.BusType -notcontains "USB" -and $target.BusType -notcontains "MMC" -and $target.BusType -notcontains "Unspecified") {
    Log "ABORT: disk $DiskNumber is BusType '$($target.BusType)', not removable." Red
    $abort = $true
}
if ($target.Size -gt 200GB) {
    Log "ABORT: disk $DiskNumber is $sizeGb GB. This guard stops you wiping a real drive." Red
    $abort = $true
}
if ($sizeGb -lt 8) {
    Log "ABORT: disk $DiskNumber is only $sizeGb GB, too small for this ISO." Red
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

Log "    The card you named is about to be COMPLETELY ERASED." Red
Log "    Everything currently on it will be gone, permanently." Red
Log ""
$confirm = Read-Host "    Type ERASE in capitals to continue, anything else to cancel"
if ($confirm -cne "ERASE") {
    Log "    Cancelled. Nothing was changed." Yellow
    return
}
Log ""

# ---------------------------------------------------------------- download ISO
Log "==> [3/6] Getting the Linux image..." Cyan

if (-not $IsoPath -or -not (Test-Path $IsoPath)) {
    $IsoPath = Join-Path $WorkDir $IsoName
}

$needIso = $true
if (Test-Path $IsoPath) {
    $existingMb = [math]::Round((Get-Item $IsoPath).Length / 1MB, 0)
    Log "    Found cached ISO: $existingMb MB"
    $needIso = $false
}

if ($needIso) {
    Log "    Downloading Lubuntu 24.04.5 amd64 (~3.8 GB). This takes a while."
    Log "    Source: $IsoUrl"
    & curl.exe -fL --retry 3 --retry-delay 3 -o $IsoPath $IsoUrl
    if (-not (Test-Path $IsoPath)) {
        Log "ERROR: ISO download failed." Red
        Log "Manual: download from https://cdimage.ubuntu.com/lubuntu/releases/noble/release/" Red
        Log "        then re-run with -IsoPath 'C:\\path\\to\\$IsoName'" Red
        return
    }
}

if ($SkipVerifyIso) {
    Log "    ISO SHA-256 verification SKIPPED (-SkipVerifyIso)." Yellow
} else {
    Log "    Verifying ISO SHA-256 against Ubuntu's published checksums..."
    $sumsFile = Join-Path $WorkDir "SHA256SUMS"
    & curl.exe -fsSL -o $sumsFile $SumsUrl
    $expected = $null
    if (Test-Path $sumsFile) {
        $line = Get-Content $sumsFile | Where-Object { $_ -match [regex]::Escape($IsoName) } | Select-Object -First 1
        if ($line) {
            $candidate = ($line -split '\s+')[0].Trim().ToLower()
            if ($candidate -match '^[0-9a-f]{64}$') { $expected = $candidate }
        }
    }
    if (-not $expected) {
        Log "    Could not read the published checksum; refusing to trust this ISO." Red
        Log "    Re-run with -SkipVerifyIso only if you downloaded it yourself from Ubuntu." Red
        return
    }
    $actual = (Get-FileHash $IsoPath -Algorithm SHA256).Hash.ToLower()
    if ($actual -ne $expected) {
        Log "ERROR: ISO checksum mismatch." Red
        Log "  expected: $expected" Red
        Log "  actual:   $actual" Red
        Log "The download is corrupt. Delete it and try again." Yellow
        return
    }
    Log "    [OK] ISO verified ($($actual.Substring(0,16))...)" Green
}

# ---------------------------------------------------------------- download shim
Log "==> [4/6] Getting the 32-bit UEFI boot shim..." Cyan
$shimPath = Join-Path $WorkDir "bootia32.efi"
if (-not (Test-Path $shimPath)) {
    & curl.exe -fL --retry 3 -o $shimPath $ShimUrl
}
if (-not (Test-Path $shimPath)) {
    Log "ERROR: could not download bootia32.efi." Red
    Log "Without it this card will not boot on Surface 3." Red
    return
}
$shimHash = (Get-FileHash $shimPath -Algorithm SHA256).Hash.ToLower()
if ($shimHash -ne $ShimSha256) {
    Log "ERROR: bootia32.efi checksum mismatch." Red
    Log "  expected: $ShimSha256" Red
    Log "  actual:   $shimHash" Red
    Log "Refusing to install an unverified bootloader." Red
    return
}
Log "    [OK] bootia32.efi verified ($($shimHash.Substring(0,16))...)" Green
Log "    Note: this is a community-built unsigned 32-bit GRUB. Secure Boot" Yellow
Log "    must be disabled on the Surface for it to load." Yellow

# ---------------------------------------------------------------- format
Log "==> [5/6] Formatting disk $DiskNumber as FAT32..." Cyan
try {
    Clear-Disk -Number $DiskNumber -RemoveData -RemoveOEM -Confirm:$false -ErrorAction Stop
} catch {
    Log "    Clear-Disk reported: $($_.Exception.Message)" Yellow
}
Initialize-Disk -Number $DiskNumber -PartitionStyle GPT -ErrorAction SilentlyContinue | Out-Null
$part = New-Partition -DiskNumber $DiskNumber -UseMaximumSize -AssignDriveLetter -ErrorAction Stop
$vol = Format-Volume -Partition $part -FileSystem FAT32 -NewFileSystemLabel "STORMRAVEN" -Confirm:$false -ErrorAction Stop
$driveLetter = $part.DriveLetter
Log "    [OK] Formatted as $driveLetter`: FAT32 label STORMRAVEN" Green
Log ""

# ---------------------------------------------------------------- copy
Log "==> [6/6] Copying Linux files and installing the 32-bit shim..." Cyan
$mount = Mount-DiskImage -ImagePath $IsoPath -PassThru -ErrorAction Stop
$isoDrive = $null
try {
    $isoDrive = ($mount | Get-Volume -ErrorAction SilentlyContinue).DriveLetter
    if (-not $isoDrive) {
        Start-Sleep -Seconds 2
        $isoDrive = ($mount | Get-Volume -ErrorAction SilentlyContinue).DriveLetter
    }
    if (-not $isoDrive) {
        Log "ERROR: could not mount the ISO." Red
        return
    }
    Log "    ISO mounted at $isoDrive`:"

    # Sanity: FAT32 cannot hold a single file over 4 GB
    $tooBig = Get-ChildItem "${isoDrive}:\" -Recurse -File -ErrorAction SilentlyContinue |
              Where-Object { $_.Length -gt 4GB } | Select-Object -First 3
    if ($tooBig) {
        Log "ERROR: the ISO contains files larger than FAT32's 4 GB limit:" Red
        foreach ($f in $tooBig) { Log "    $($f.FullName) = $([math]::Round($f.Length/1GB,2)) GB" Red }
        Log "Use a different ISO (a smaller spin of Ubuntu or Debian)." Yellow
        return
    }

    Log "    Copying (several minutes, do not unplug the card)..."
    $srcRoot = "${isoDrive}:\"
    $dstRoot = "${driveLetter}:\"
    $rc = Start-Process -FilePath "robocopy.exe" `
        -ArgumentList @($srcRoot, $dstRoot, "/E", "/NFL", "/NDL", "/NJH", "/NJS", "/R:1", "/W:1") `
        -Wait -PassThru -NoNewWindow
    if ($rc.ExitCode -ge 8) {
        Log "ERROR: copy failed (robocopy exit $($rc.ExitCode))." Red
        return
    }
    Log "    [OK] ISO contents copied." Green
} finally {
    Dismount-DiskImage -ImagePath $IsoPath -ErrorAction SilentlyContinue | Out-Null
}

# Install the 32-bit EFI shim -- this is the step stock guides omit
$efiBootDir = "$driveLetter`:\EFI\BOOT"
if (-not (Test-Path $efiBootDir)) {
    New-Item -ItemType Directory -Force -Path $efiBootDir | Out-Null
}
Copy-Item $shimPath (Join-Path $efiBootDir "BOOTIA32.EFI") -Force
Log "    [OK] Installed \EFI\BOOT\BOOTIA32.EFI (32-bit UEFI shim)" Green

# ---------------------------------------------------------------- verify
Log ""
Log "==> Verifying the card layout:" Cyan
$checks = @(
    "EFI\BOOT\BOOTIA32.EFI",
    "EFI\BOOT\BOOTX64.EFI",
    "casper\vmlinuz",
    "casper\initrd"
)
foreach ($c in $checks) {
    $p = Join-Path "$driveLetter`:\" $c
    $exists = Test-Path $p
    $mark = if ($exists) { "[OK]  " } else { "[MISS]" }
    $color = if ($exists) { "Gray" } else { "Yellow" }
    Log "    $mark $c" $color
}

$usedGb = [math]::Round(((Get-Partition -DriveLetter $driveLetter | Get-Volume).Size - (Get-Partition -DriveLetter $driveLetter | Get-Volume).SizeRemaining) / 1GB, 1)
Log "    Space used: $usedGb GB"

Log ""
Log "=======================================================================" Green
Log " * SD CARD IS READY" Green
Log "=======================================================================" Green
Log ""
Log "Boot it on the Surface 3:" Cyan
Log "  1. Turn OFF the Surface (full shutdown, not sleep)." White
Log "  2. Hold VOLUME DOWN, then press POWER. Keep holding Volume Down" White
Log "     until the Surface logo appears. That enters the boot device menu." White
Log "  3. Pick the SD card / USB storage device." White
Log "  4. If it refuses to boot, disable Secure Boot:" White
Log "     power off, hold VOLUME UP + POWER, UEFI > Security > Secure Boot > Disable." White
Log ""
Log "Expect a red boot screen when Secure Boot is off -- that is normal for unsigned" Yellow
Log "loaders and does not mean anything is broken." Yellow
Log ""
Log "On 2 GB RAM the live desktop will be slow. At the installer's partitioning" Yellow
Log "step, install to the internal drive for speed, or to the SD card if you want" Yellow
Log "Windows untouched -- but SD writes are slow and cards wear out." Yellow
Log ""
Log "Log file: $LogPath" White
