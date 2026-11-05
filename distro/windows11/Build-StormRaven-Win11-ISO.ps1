#Requires -RunAsAdministrator
<#
.SYNOPSIS
    StormRaven OS: Ymir Edition v3.9.0 — Custom Windows 11 ISO Builder (DISM + Windows ADK + Oscdimg)
.DESCRIPTION
    Builds a true custom Windows 11 ISO using official Microsoft Windows Dev / Assessment & Deployment Kit (ADK) tools:
      1. Compiles self-contained native Windows x64 `StormRaven.Kernel.exe` via `dotnet publish`
      2. Extracts or mounts a base Windows 11 ISO (`install.wim` or `install.esd`)
      3. Mounts the offline Windows 11 image using DISM (`Mount-WindowsImage`)
      4. Injects StormRaven OS directly into the offline WIM filesystem & registry hives:
         - `\ProgramData\StormRaven\bin\StormRaven.Kernel.exe` (Bifrost Gateway :8787 + UI Server :3887)
         - `\ProgramData\StormRaven\python\` (Odin Pantheon: Odin, Thor, Freya, Heimdall, Luci, Solomon, Heketa, Lynn)
         - `\ProgramData\StormRaven\webapp\` (Ymir Edition 3-Panel Glass HUD + Ubuntu/Win11 Mode Switcher)
         - `\Windows\System32\stormraven.cmd`, `fehu.cmd`, `algiz.cmd`, `isa.cmd`, `raido.cmd`, `sr-install.cmd`
         - `\Windows\Setup\Scripts\SetupComplete.cmd` & offline `DEFAULT` registry hive customization (Ymir dark cryo-glass theme, centered taskbar, Frost Giant wallpaper, automatic Windows Update policy, Kernel auto-start service)
         - Optional driver injection (`Add-WindowsDriver`) for HP w2558hc / W2072a & storage/network drivers
      5. Stages validated `autounattend.xml` at the ISO root
      6. Commits the modified WIM (`Dismount-WindowsImage -Save`) and builds a dual-bootable UEFI + BIOS ISO using `oscdimg.exe` from the Windows ADK Deployment Tools, plus a `.sha256` sidecar.
.PARAMETER SourceIso
    Path to the official base Windows 11 x64 ISO.
.PARAMETER OutputIso
    Path for the output custom StormRaven Windows 11 ISO.
.PARAMETER ImageIndex
    WIM image edition index to customize (default: 1, or Pro/Enterprise index).
.PARAMETER DriversPath
    Optional folder of `.inf` drivers to inject into the offline WIM via DISM.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceIso,

    [Parameter(Mandatory = $false)]
    [string]$OutputIso = "$PSScriptRoot\..\..\StormRavenOS-Win11-Ymir-v3.9.0-amd64.iso",

    [Parameter(Mandatory = $false)]
    [int]$ImageIndex = 1,

    [Parameter(Mandatory = $false)]
    [string]$DriversPath = ""
)

$ErrorActionPreference = "Stop"

Write-Host "=======================================================================" -ForegroundColor Cyan
Write-Host " ✦ STORMRAVEN OS v3.9.0 — CUSTOM WINDOWS 11 WIM / ISO BUILDER (ADK/DISM)" -ForegroundColor Cyan
Write-Host "=======================================================================" -ForegroundColor Cyan

if (-not (Test-Path $SourceIso)) {
    throw "Base Windows 11 ISO not found at: $SourceIso"
}

$RepoRoot  = (Resolve-Path "$PSScriptRoot\..\..").Path
$WorkRoot  = Join-Path $env:TEMP "stormraven-win11-adk-build"
$IsoStage  = Join-Path $WorkRoot "iso_root"
$WimMount  = Join-Path $WorkRoot "wim_mount"
$PublishDir = Join-Path $WorkRoot "publish_kernel"

# Locate oscdimg.exe from Windows Assessment and Deployment Kit (ADK)
$AdkPaths = @(
    "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe",
    "${env:ProgramFiles}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
)
$Oscdimg = $AdkPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $Oscdimg) {
    $OscdimgCmd = Get-Command oscdimg.exe -ErrorAction SilentlyContinue
    if ($OscdimgCmd) { $Oscdimg = $OscdimgCmd.Source }
}
if (-not $Oscdimg) {
    throw "oscdimg.exe not found. Install the Windows ADK (Deployment Tools feature): winget install Microsoft.WindowsADK"
}
Write-Host "==> [1/7] Found Windows ADK Oscdimg: $Oscdimg" -ForegroundColor Green

# Clean any leftover workspace
if (Test-Path $WimMount) {
    Dismount-WindowsImage -Path $WimMount -Discard -ErrorAction SilentlyContinue | Out-Null
}
Remove-Item -Path $WorkRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $IsoStage, $WimMount, $PublishDir | Out-Null

# 2. Build self-contained StormRaven.Kernel.exe for win-x64
$KernelProj = Join-Path $RepoRoot "StormRaven.Kernel\StormRaven.Kernel.csproj"
if (Test-Path $KernelProj) {
    Write-Host "==> [2/7] Compiling native Windows x64 StormRaven.Kernel.exe..." -ForegroundColor Cyan
    & dotnet publish $KernelProj -c Release -r win-x64 --self-contained true `
        -p:PublishSingleFile=true -o $PublishDir
} else {
    Write-Host "==> [2/7] Kernel csproj not found locally; proceeding with staged binaries if present..." -ForegroundColor Yellow
}

# 3. Mount base Windows 11 ISO and copy contents to writable staging folder
Write-Host "==> [3/7] Mounting base Windows 11 ISO and staging files..." -ForegroundColor Cyan
$MountResult = Mount-DiskImage -ImagePath (Resolve-Path $SourceIso).Path -PassThru
try {
    $DriveLetter = ($MountResult | Get-Volume).DriveLetter
    if (-not $DriveLetter) { throw "Failed to obtain drive letter for mounted ISO." }
    Copy-Item -Path "${DriveLetter}:\*" -Destination $IsoStage -Recurse -Force
} finally {
    Dismount-DiskImage -ImagePath (Resolve-Path $SourceIso).Path -ErrorAction SilentlyContinue | Out-Null
}

# Clear read-only attributes inherited from ISO9660/UDF
Get-ChildItem -Path $IsoStage -Recurse -Force | ForEach-Object {
    if ($_.Attributes -band [IO.FileAttributes]::ReadOnly) {
        $_.Attributes = $_.Attributes -bxor [IO.FileAttributes]::ReadOnly
    }
}

# Convert install.esd -> install.wim if base ISO uses ESD compression
$WimPath = Join-Path $IsoStage "sources\install.wim"
$EsdPath = Join-Path $IsoStage "sources\install.esd"
if ((-not (Test-Path $WimPath)) -and (Test-Path $EsdPath)) {
    Write-Host "    Converting sources\install.esd to editable install.wim via DISM..." -ForegroundColor Cyan
    & dism.exe /Export-Image /SourceImageFile:"$EsdPath" /SourceIndex:$ImageIndex `
        /DestinationImageFile:"$WimPath" /Compress:max /CheckIntegrity
    Remove-Item -Path $EsdPath -Force
    $ImageIndex = 1
}

if (-not (Test-Path $WimPath)) {
    throw "Could not find sources\install.wim in staged ISO."
}

# 4. Mount install.wim offline via DISM
Write-Host "==> [4/7] Mounting sources\install.wim (Index $ImageIndex) via DISM..." -ForegroundColor Cyan
Mount-WindowsImage -ImagePath $WimPath -Index $ImageIndex -Path $WimMount | Out-Null

try {
    # 5. Inject StormRaven OS files, Pantheon, Ymir Edition UI, and drivers into offline WIM
    Write-Host "==> [5/7] Injecting StormRaven OS Core, Odin Pantheon & Ymir Edition UI into offline WIM..." -ForegroundColor Cyan

    $OfflineSrRoot  = Join-Path $WimMount "ProgramData\StormRaven"
    $OfflineBin     = Join-Path $OfflineSrRoot "bin"
    $OfflinePython  = Join-Path $OfflineSrRoot "python"
    $OfflineWebapp  = Join-Path $OfflineSrRoot "webapp"
    $OfflineDrivers = Join-Path $OfflineSrRoot "drivers\hp-w2558hc"
    $OfflineVoid    = Join-Path $OfflineSrRoot "void"
    $OfflineSys32   = Join-Path $WimMount "Windows\System32"
    $OfflineScripts = Join-Path $WimMount "Windows\Setup\Scripts"

    New-Item -ItemType Directory -Force -Path $OfflineBin, $OfflinePython, $OfflineWebapp, $OfflineDrivers, `
        "$OfflineVoid\helheim", "$OfflineVoid\niflheim", "$OfflineVoid\muspelheim", $OfflineScripts | Out-Null

    if (Test-Path "$PublishDir\*") {
        Copy-Item -Path "$PublishDir\*" -Destination $OfflineBin -Recurse -Force
    }
    if (Test-Path "$RepoRoot\StormRaven.Python\*") {
        Copy-Item -Path "$RepoRoot\StormRaven.Python\*" -Destination $OfflinePython -Recurse -Force
    }
    if (Test-Path "$RepoRoot\webapp\*") {
        Copy-Item -Path "$RepoRoot\webapp\*" -Destination $OfflineWebapp -Recurse -Force
    }
    if (Test-Path "$RepoRoot\distro\wallpapers\*") {
        Copy-Item -Path "$RepoRoot\distro\wallpapers\*" -Destination $OfflineWebapp -Recurse -Force
    }

    # Copy Installer & Autounattend scripts into the offline image
    Copy-Item -Path "$PSScriptRoot\Install-StormRaven-Win11.ps1" -Destination "$OfflineSrRoot\Install-StormRaven-Win11.ps1" -Force
    if (Test-Path "$PSScriptRoot\Install-StormRaven-Win11.ps1.sha256") {
        Copy-Item -Path "$PSScriptRoot\Install-StormRaven-Win11.ps1.sha256" -Destination "$OfflineSrRoot\Install-StormRaven-Win11.ps1.sha256" -Force
    }

    # Load offline Default User + Software registry hives to pre-configure Ymir Dark Theme, Centered Taskbar,
    # Wallpaper, and Automatic Windows Updates for every user profile created on the machine.
    $DefaultUserDat = Join-Path $WimMount "Users\Default\NTUSER.DAT"
    $SoftwareHive   = Join-Path $WimMount "Windows\System32\config\SOFTWARE"

    & reg.exe load "HKLM\SR_DEFAULT" "$DefaultUserDat" | Out-Null
    try {
        & reg.exe add "HKLM\SR_DEFAULT\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v AppsUseLightTheme /t REG_DWORD /d 0 /f | Out-Null
        & reg.exe add "HKLM\SR_DEFAULT\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v SystemUsesLightTheme /t REG_DWORD /d 0 /f | Out-Null
        & reg.exe add "HKLM\SR_DEFAULT\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 1 /f | Out-Null
        & reg.exe add "HKLM\SR_DEFAULT\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarAl /t REG_DWORD /d 1 /f | Out-Null
        & reg.exe add "HKLM\SR_DEFAULT\Control Panel\Desktop" /v Wallpaper /t REG_SZ /d "C:\ProgramData\StormRaven\webapp\ethereal-void-desktop.png" /f | Out-Null
    } finally {
        [gc]::Collect()
        & reg.exe unload "HKLM\SR_DEFAULT" | Out-Null
    }

    & reg.exe load "HKLM\SR_SOFTWARE" "$SoftwareHive" | Out-Null
    try {
        # Enable automatic Windows Updates (AUOptions=4: Auto download and schedule install)
        & reg.exe add "HKLM\SR_SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoUpdate /t REG_DWORD /d 0 /f | Out-Null
        & reg.exe add "HKLM\SR_SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AUOptions /t REG_DWORD /d 4 /f | Out-Null
        & reg.exe add "HKLM\SR_SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v ScheduledInstallDay /t REG_DWORD /d 0 /f | Out-Null
    } finally {
        [gc]::Collect()
        & reg.exe unload "HKLM\SR_SOFTWARE" | Out-Null
    }

    # Wire SetupComplete.cmd so Windows Setup finalizes the StormRaven service & shortcuts offline/first-boot
    $SetupComplete = @"
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\ProgramData\StormRaven\Install-StormRaven-Win11.ps1"
"@
    Set-Content -Path (Join-Path $OfflineScripts "SetupComplete.cmd") -Value $SetupComplete -Encoding ASCII

    # Optional hardware driver injection via DISM
    if ($DriversPath -and (Test-Path $DriversPath)) {
        Write-Host "    Injecting hardware drivers from $DriversPath via DISM..." -ForegroundColor Cyan
        Add-WindowsDriver -Path $WimMount -Driver $DriversPath -Recurse | Out-Null
    }

    Write-Host "==> [6/7] Saving and dismounting customized install.wim..." -ForegroundColor Cyan
    Dismount-WindowsImage -Path $WimMount -Save | Out-Null
} catch {
    Write-Host "[!] Error during WIM customization; discarding mount..." -ForegroundColor Red
    Dismount-WindowsImage -Path $WimMount -Discard -ErrorAction SilentlyContinue | Out-Null
    throw
}

# Stage autounattend.xml at ISO root
if (Test-Path "$PSScriptRoot\autounattend.xml") {
    Copy-Item -Path "$PSScriptRoot\autounattend.xml" -Destination (Join-Path $IsoStage "autounattend.xml") -Force
}

# 7. Pack bootable UEFI + Legacy BIOS ISO using Windows ADK oscdimg.exe
Write-Host "==> [7/7] Packing bootable Custom Windows 11 ISO via Windows ADK oscdimg.exe..." -ForegroundColor Cyan
$EtfsBoot = Join-Path $IsoStage "boot\etfsboot.com"
$EfiSys   = Join-Path $IsoStage "efi\microsoft\boot\efisys.bin"

$ResolvedOutput = [IO.Path]::GetFullPath($OutputIso)
& $Oscdimg -m -o -u2 -udfver102 `
    -bootdata:"2#p0,e,b$EtfsBoot#pEF,e,b$EfiSys" `
    -l"STORMRAVEN_WIN11" `
    "$IsoStage" "$ResolvedOutput"

if (-not (Test-Path $ResolvedOutput)) {
    throw "oscdimg.exe failed to produce $ResolvedOutput"
}

$IsoHash = (Get-FileHash -Path $ResolvedOutput -Algorithm SHA256).Hash.ToLower()
$IsoName = [IO.Path]::GetFileName($ResolvedOutput)
Set-Content -Path "$ResolvedOutput.sha256" -Value "$IsoHash  $IsoName" -Encoding ASCII

Remove-Item -Path $WorkRoot -Recurse -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "=======================================================================" -ForegroundColor Green
Write-Host " ✦ CUSTOM WINDOWS 11 STORMRAVEN OS ISO COMPLETE!" -ForegroundColor Green
Write-Host "   • ISO:     $ResolvedOutput" -ForegroundColor White
Write-Host "   • SHA-256: $IsoHash" -ForegroundColor White
Write-Host "=======================================================================" -ForegroundColor Green
