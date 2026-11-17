#StormRaven OS v3.9.0 -- Microsoft Surface 3 EFI Boot Pack Installer (Windows PowerShell)
# Regression story (Issue #108, 2026-11-16 Surface 3 incident; pattern source #87):
#   A boot-repair sequence from Windows RE used 'assign letter=S' on an ambiguous
#   disk selection in a multi-drive machine (58GB SSD + 119GB microSD + 465GB
#   external USB all attached). Firmware 'Boot Option Restoration' auto-reset
#   boot config and caused a 1-hour red-screen bootloop.
#   Rule: Verify target USB volume by Model / Serial / Volume Label / Size before
#   any write, support -VerifyMode, refuse the Windows OS/boot disk, and require
#   explicit confirmation ("ERASE" or "UPDATE-EFI") before writing.
#
# Tested paste-ready one-liner (Admin PowerShell):
#   cd $env:TEMP; curl.exe -fsSLO https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/Make-Surface3-USB.ps1; curl.exe -fsSLO https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/Make-Surface3-USB.ps1.sha256; if ((Get-FileHash .\Make-Surface3-USB.ps1 -Algorithm SHA256).Hash.ToLower() -ne (Get-Content .\Make-Surface3-USB.ps1.sha256).Split(' ')[0].Trim().ToLower()) { throw 'SHA-256 mismatch' }; powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Make-Surface3-USB.ps1 -VerifyMode
param(
    [string]$TargetLabel = "STORMRAVEN",
    [string]$TargetUniqueId = "",
    [switch]$VerifyMode,
    [string]$UsbDriveLetter = "",
    [switch]$ConfirmWrite
)
$ErrorActionPreference = "Stop"

if ($VerifyMode) {
    Write-Host "==> CORE #108 VERIFY-MODE: Disks & Volumes on this machine:" -ForegroundColor Cyan
    $disks = Get-Disk -ErrorAction SilentlyContinue | Sort-Object Number
    foreach ($d in $disks) {
        $sizeGb = [math]::Round($d.Size / 1GB, 1)
        $serial = if ($d.SerialNumber) { $d.SerialNumber.Trim() } else { $d.UniqueId }
        $vols = @(Get-Partition -DiskNumber $d.Number -ErrorAction SilentlyContinue | Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.FileSystemLabel } | ForEach-Object { "$($_.DriveLetter):$($_.FileSystemLabel)" }) -join ","
        if (-not $vols) { $vols = "unlabeled" }
        Write-Host ("    Disk {0,-2} {1,-6} {2,7} GB  Model={3}  Serial={4}  Labels=[{5}]" -f $d.Number, $d.BusType, $sizeGb, $d.FriendlyName, $serial, $vols)
    }
    $wanted = Read-Host "Enter the exact Serial or Volume Label of the intended target drive"
    if (-not $wanted) {
        Write-Host "CRITICAL: Empty serial/label entered in -VerifyMode. Failing closed." -ForegroundColor Red
        exit 1
    }
    $TargetUniqueId = $wanted.Trim()
}

$vol = $null
if ($TargetUniqueId) {
    $matchedDisk = Get-Disk -ErrorAction SilentlyContinue | Where-Object {
        ($_.UniqueId -and $_.UniqueId.Trim() -eq $TargetUniqueId) -or
        ($_.SerialNumber -and $_.SerialNumber.Trim() -eq $TargetUniqueId)
    } | Select-Object -First 1
    if ($matchedDisk) {
        $vol = Get-Partition -DiskNumber $matchedDisk.Number -ErrorAction SilentlyContinue | Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.FileSystem -eq "FAT32" } | Select-Object -First 1
    } else {
        $vol = Get-Volume -FileSystemLabel $TargetUniqueId -ErrorAction SilentlyContinue | Select-Object -First 1
    }
}
if (-not $vol -and $TargetLabel) {
    $vol = Get-Volume -FileSystemLabel $TargetLabel -ErrorAction SilentlyContinue | Select-Object -First 1
}
if (-not $vol -and $UsbDriveLetter) {
    $dl = $UsbDriveLetter.TrimEnd(':', '\')
    $vol = Get-Volume -DriveLetter $dl -ErrorAction SilentlyContinue | Select-Object -First 1
}
if (-not $vol -or -not $vol.DriveLetter) {
    Write-Host "CRITICAL: Target USB volume (Label='$TargetLabel' Drive='$UsbDriveLetter') was not found. Failing closed." -ForegroundColor Red
    exit 1
}

$DriveLetter = [string]$vol.DriveLetter
if ($DriveLetter -eq "C" -or "${DriveLetter}:" -eq $env:SystemDrive) {
    Write-Host "CRITICAL: Refusing to write EFI bootloaders onto system drive ${DriveLetter}:. Failing closed." -ForegroundColor Red
    exit 1
}
if ($vol.FileSystem -ne "FAT32") {
    Write-Host "CRITICAL: Target volume ${DriveLetter}: ($($vol.FileSystemLabel)) is $($vol.FileSystem), not FAT32. Failing closed." -ForegroundColor Red
    exit 1
}

$Drive = "${DriveLetter}:"
$sizeGb = [math]::Round($vol.Size / 1GB, 2)
$partObj = $vol | Get-Partition -ErrorAction SilentlyContinue | Select-Object -First 1
$diskObj = if ($partObj) { Get-Disk -Number $partObj.DiskNumber -ErrorAction SilentlyContinue } else { $null }
$diskModel = if ($diskObj) { $diskObj.FriendlyName } else { "Unknown" }
$diskSerial = if ($diskObj -and $diskObj.SerialNumber) { $diskObj.SerialNumber.Trim() } elseif ($diskObj) { $diskObj.UniqueId } else { "Unknown" }

Write-Host "RESOLVED TARGET:" -ForegroundColor Cyan
Write-Host "  Drive      : $Drive\"
Write-Host "  Model      : $diskModel"
Write-Host "  Serial     : $diskSerial"
Write-Host "  Label      : $($vol.FileSystemLabel)"
Write-Host "  FileSystem : $($vol.FileSystem)"
Write-Host "  Size       : $sizeGb GB"
Write-Host ""

if (-not $ConfirmWrite) {
    $ans = Read-Host "Type ERASE (or UPDATE-EFI) in capitals to confirm writing Surface 3 EFI bootloaders to $Drive\ (Label=$($vol.FileSystemLabel))"
    if ($ans -cne "ERASE" -and $ans -cne "UPDATE-EFI") {
        Write-Host "Cancelled. Nothing was written." -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "[STEP 1/2] Downloading and verifying Surface3-EFI-BootPack.zip SHA-256..." -ForegroundColor Cyan
$zipFile = "$env:TEMP\Surface3-EFI-BootPack.zip"
$shaFile = "$env:TEMP\Surface3-EFI-BootPack.zip.sha256"
& curl.exe -fsSL -o $zipFile "https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/Surface3-EFI-BootPack.zip"
& curl.exe -fsSL -o $shaFile "https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app/Surface3-EFI-BootPack.zip.sha256"
$expected = (Get-Content $shaFile).Split(' ')[0].Trim().ToLower()
$actual = (Get-FileHash $zipFile -Algorithm SHA256).Hash.ToLower()
if ($actual -ne $expected) { throw "SHA-256 mismatch!" }

Write-Host "[STEP 2/2] Extracting dual BOOTX64.EFI + BOOTIA32.EFI onto verified target $Drive\ ($($vol.FileSystemLabel))..." -ForegroundColor Cyan
Expand-Archive -Path $zipFile -DestinationPath "$Drive\" -Force
Write-Host "Surface 3 EFI Bootloaders installed on $Drive\EFI\BOOT\ (BOOTX64.EFI + BOOTIA32.EFI)!" -ForegroundColor Green
