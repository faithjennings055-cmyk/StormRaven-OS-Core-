
# StormRaven Deployment Script

$releasePath = $PSScriptRoot
$shellExe = Join-Path $releasePath "StormRaven.Shell\StormRaven.Shell.exe"

Write-Host "Starting StormRaven Deployment..." -ForegroundColor Cyan

# 0. Pre-flight Checks
if (-not (Test-Path -Path $shellExe -PathType Leaf)) {
    Write-Error "CRITICAL: StormRaven.Shell.exe not found at '$shellExe'. Deployment cannot continue."
    exit 1
}

# 1. Check Prerequisite: Python
if (-not (Get-Command "python" -ErrorAction SilentlyContinue)) {
    Write-Warning "Python is not found in PATH. Some features (StormRaven.Python) may not function correctly."
    Write-Warning "Please install Python from python.org or the Microsoft Store."
}
else {
    $pyVersion = python --version 2>&1
    Write-Host "Python detected: $pyVersion" -ForegroundColor Green
}

# 2. Create Desktop Shortcut
try {
    $desktopPath = [System.Environment]::GetFolderPath('Desktop')
    $shortcutPath = Join-Path $desktopPath "StormRaven Shell.lnk"
    
    $wshShell = New-Object -ComObject WScript.Shell
    $shortcut = $wshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $shellExe
    $shortcut.WorkingDirectory = Join-Path $releasePath "StormRaven.Shell"
    $shortcut.Description = "Launch StormRaven Shell"
    $shortcut.Save()

    Write-Host "Shortcut created successfully at: $shortcutPath" -ForegroundColor Green
    Write-Host "Deployment Complete. You can now launch StormRaven Shell from your desktop." -ForegroundColor Cyan
}
catch {
    Write-Error "Failed to create desktop shortcut: $_"
    exit 1
}
