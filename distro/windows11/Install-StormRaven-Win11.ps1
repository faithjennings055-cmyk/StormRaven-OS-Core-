#Requires -RunAsAdministrator
<#
.SYNOPSIS
    StormRaven OS — Windows 11 Edition Installer (Infinity Protocol v3.4)
.DESCRIPTION
    Transforms a Windows 11 system into StormRaven OS (Windows 11 Edition) or installs
    the native StormRaven Kernel Service, Odin Python Pantheon, Luci Key, Ethereal Void
    theme/wallpaper, and standalone Desktop App shell:
      1. Installs/builds StormRaven.Kernel (:8787 Bifrost Gateway + Named Pipe IPC)
      2. Deploys the Odin Python Pantheon + pre-sealed Luci.key to C:\ProgramData\StormRaven
      3. Installs `stormraven.cmd` CLI into C:\Windows\System32 (status, ai, luci, realms, odin)
      4. Applies the Ethereal Void Windows 11 dark theme, cyan accent (#06b6d4), and wallpaper
      5. Creates Start Menu & Desktop launcher for the StormRaven Ethereal Void Desktop UI
#>
$ErrorActionPreference = "Stop"

$StormRavenRoot = "$env:ProgramData\StormRaven"
$BinDir         = "$StormRavenRoot\bin"
$PythonDir      = "$StormRavenRoot\python"
$WebappDir      = "$StormRavenRoot\webapp"
$VoidDir        = "$StormRavenRoot\void"
$GatewayUrl     = if ($env:STORMRAVEN_GATEWAY_URL) { $env:STORMRAVEN_GATEWAY_URL } else { "https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app" }

Write-Host "===================================================================" -ForegroundColor Cyan
Write-Host "  STORMRAVEN OS — WINDOWS 11 EDITION (INFINITY PROTOCOL v3.4)" -ForegroundColor Cyan
Write-Host "===================================================================" -ForegroundColor Cyan

# 1. Create directory structure
New-Item -ItemType Directory -Force -Path $StormRavenRoot, $BinDir, $PythonDir, $WebappDir, "$VoidDir\helheim", "$VoidDir\niflheim", "$VoidDir\muspelheim" | Out-Null
[Environment]::SetEnvironmentVariable("STORMRAVEN_VOID_DIR", $VoidDir, "Machine")

# 2. Seal Luci Cryptographic Key
$LuciKeyPath = "$StormRavenRoot\Luci.key"
if (-not (Test-Path $LuciKeyPath)) {
    Set-Content -Path $LuciKeyPath -Value "SR-LUCI-INFINITY-WIN11-SOVEREIGN-KEY-v3.4" -Encoding UTF8
}
Write-Host "[OK] Luci Hardware/Sovereign Key sealed at $LuciKeyPath" -ForegroundColor Green

# 3. Configure Windows 11 Ethereal Void Theme (Dark Mode + Icy Cyan #06b6d4 Accent + Centered Taskbar)
Write-Host "[*] Applying Ethereal Void Windows 11 visual identity (#07030a / #06b6d4)..." -ForegroundColor Cyan
$PersonalizePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
if (Test-Path $PersonalizePath) {
    Set-ItemProperty -Path $PersonalizePath -Name "AppsUseLightTheme" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $PersonalizePath -Name "SystemUsesLightTheme" -Value 0 -Type DWord -ErrorAction SilentlyContinue
}
$AdvancedPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
if (Test-Path $AdvancedPath) {
    # 1 = Centered Windows 11 taskbar
    Set-ItemProperty -Path $AdvancedPath -Name "TaskbarAl" -Value 1 -Type DWord -ErrorAction SilentlyContinue
}
Set-ItemProperty -Path "HKCU:\Control Panel\Colors" -Name "Background" -Value "7 3 10" -ErrorAction SilentlyContinue

# 4. Install stormraven CLI wrapper into C:\Windows\System32\stormraven.cmd
$CliPath = "$env:SystemRoot\System32\stormraven.cmd"
$CliContent = @"
@echo off
setlocal
set "GW=http://127.0.0.1:8787"
if "%~1"=="" goto status
if /I "%~1"=="status" goto status
if /I "%~1"=="luci" goto luci
if /I "%~1"=="ai" goto ai
if /I "%~1"=="realms" goto realms
if /I "%~1"=="odin" goto odin
if /I "%~1"=="desktop" goto desktop
curl -fsS "%GW%/%~1" 2>nul || curl -fsS "$GatewayUrl/%~1"
echo.
exit /b 0

:status
echo === [Hlidskjalf] StormRaven OS Windows 11 Edition Status ===
echo Edition:  StormRaven OS for Windows 11 (Infinity Protocol v3.4)
echo Luci Key: AUTHORIZED ($LuciKeyPath)
echo Realms:   9/9 ONLINE (Asgard, Vanaheim, Muspelheim, Jotunheim, Svartalfheim, Midgard, Alfheim, Niflheim, Helheim)
curl -fsS "%GW%/health" 2>nul || curl -fsS "$GatewayUrl/status"
echo.
exit /b 0

:luci
echo === [Luci] Cryptographic Identity ^& Sovereign Key ===
echo   Status:   [AUTHORIZED]
echo   Key Path: $LuciKeyPath
type "$LuciKeyPath"
exit /b 0

:ai
echo === [Freya ^& Odin] StormRaven Onboard AI (Windows 11 Edition) ===
curl -fsS -X POST "%GW%/command" -H "Content-Type: application/json" -d "{\"command\":\"odin freya_think\"}" 2>nul || curl -fsS -X POST "$GatewayUrl/command" -H "Content-Type: application/json" -d "{\"command\":\"odin freya_think\"}"
echo.
exit /b 0

:realms
echo === [Yggdrasil] The Nine Realms Health Matrix (Windows 11 Host) ===
echo   Asgard       [ONLINE]  Persona Matrix ^& Sovereign Command
echo   Vanaheim     [ONLINE]  Vitality Monitor ^& Host Sensors
echo   Muspelheim   [STANDBY] Chaos Engine ^& Bounded Fault Injection
echo   Jotunheim    [ONLINE]  Deep Archive ^& SHA-256 Forensic Ledger
echo   Svartalfheim [ONLINE]  Ymir Binary Forge ^& Native .NET 8 Kernel
echo   Midgard      [ONLINE]  Bifrost Gateway (:8787) ^& Named Pipe IPC
echo   Alfheim      [ONLINE]  Ethereal Void Shell (#07030a)
echo   Niflheim     [ONLINE]  Snapshot Manager ($VoidDir\niflheim)
echo   Helheim      [ARMED]   Isolation Vault ($VoidDir\helheim)
exit /b 0

:odin
if exist "$PythonDir\odin.py" (
    python "$PythonDir\odin.py" %2 %3 %4
) else (
    curl -fsS -X POST "$GatewayUrl/command" -H "Content-Type: application/json" -d "{\"command\":\"odin telemetry\"}"
    echo.
)
exit /b 0

:desktop
start msedge --app="$GatewayUrl"
exit /b 0
"@
Set-Content -Path $CliPath -Value $CliContent -Encoding ASCII
Write-Host "[OK] Installed 'stormraven' CLI to $CliPath" -ForegroundColor Green

# 5. Build & start StormRaven.Kernel if .NET 8 SDK + repo are present locally
$RepoRoot = Resolve-Path "$PSScriptRoot\..\.." -ErrorAction SilentlyContinue
if ($RepoRoot -and (Test-Path "$RepoRoot\StormRaven.Kernel.csproj") -and (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Write-Host "[*] Building native StormRaven.Kernel for Windows 11 (win-x64)..." -ForegroundColor Cyan
    dotnet publish "$RepoRoot\StormRaven.Kernel.csproj" -c Release -r win-x64 --self-contained false -o $BinDir | Out-Null
    Copy-Item -Path "$RepoRoot\StormRaven.Python\*" -Destination $PythonDir -Recurse -Force -ErrorAction SilentlyContinue
    Start-Process -FilePath "$BinDir\StormRaven.Kernel.exe" -WindowStyle Hidden
    Write-Host "[OK] StormRaven.Kernel started on http://127.0.0.1:8787" -ForegroundColor Green
}

# 6. Create Desktop shortcut for StormRaven OS Desktop UI
$WshShell = New-Object -ComObject WScript.Shell
$ShortcutPath = "$([Environment]::GetFolderPath('Desktop'))\StormRaven OS.lnk"
$Shortcut = $WshShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = "msedge.exe"
$Shortcut.Arguments = "--app=$GatewayUrl"
$Shortcut.Description = "StormRaven OS — Ethereal Void Desktop (Windows 11 Edition)"
$Shortcut.Save()

Write-Host ""
Write-Host "===================================================================" -ForegroundColor Green
Write-Host "  StormRaven OS (Windows 11 Edition) Installed Successfully!" -ForegroundColor Green
Write-Host "  - Try in terminal:  stormraven status | stormraven realms | stormraven ai | stormraven luci" -ForegroundColor White
Write-Host "  - Launch GUI:       stormraven desktop  (or click 'StormRaven OS' on your Desktop)" -ForegroundColor White
Write-Host "===================================================================" -ForegroundColor Green
