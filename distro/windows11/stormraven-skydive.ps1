# =============================================================================
# StormRaven OS (Windows 11 Ymir Edition) — Skydive Desktop & CLI Wrapper (#103)
# Launches Skydive in a native chromeless Edge WebView2/App window or starts
# the local Skydive CLI Portal on Windows 11.
# =============================================================================
param(
    [string]$Mode = "gui",
    [string]$Url = "https://skydive.com"
)

if ($Mode -eq "cli" -or $Mode -eq "chat" -or $Mode -eq "portal") {
    if (Get-Command skydive -ErrorAction SilentlyContinue) {
        & skydive chat
        exit 0
    }
    Write-Host "[StormRaven Skydive Wrapper] Launching Skydive Web Workspace: $Url"
}

$edgePaths = @(
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
    "${env:ProgramFiles}\Microsoft\Edge\Application\msedge.exe"
)
foreach ($p in $edgePaths) {
    if (Test-Path $p) {
        Start-Process -FilePath $p -ArgumentList "--app=$Url --new-window"
        Write-Host "[StormRaven Skydive Wrapper] Launched Skydive native app window via Microsoft Edge WebView."
        exit 0
    }
}

Start-Process $Url
