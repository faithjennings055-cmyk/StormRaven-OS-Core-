@echo off
REM ===========================================================================
REM StormRaven OS: Container-Native Windows v4.0 OEM Provisioner (#98)
REM Runs automatically inside dockur/windows on first boot.
REM Enforces strict SHA-256 verification before executing install-win11.ps1.
REM ===========================================================================
PowerShell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference = 'Stop'; ^
   $localPs1 = 'C:\stormraven-win11-bundle\install-win11.ps1'; ^
   $localSha = 'C:\stormraven-win11-bundle\install-win11.ps1.sha256'; ^
   if ((Test-Path $localPs1) -and (Test-Path $localSha)) { ^
     $expected = ((Get-Content $localSha -Raw).Trim() -split '\s+')[0].ToLower(); ^
     $actual = (Get-FileHash -Path $localPs1 -Algorithm SHA256).Hash.ToLower(); ^
     if ($actual -ne $expected) { throw 'SHA-256 mismatch on mounted install-win11.ps1' }; ^
     & $localPs1; ^
   } else { ^
     $url = 'https://01a11428-2aab-7e12-9d89-3543f658a191.skydive.app'; ^
     Invoke-WebRequest -UseBasicParsing -Uri \"$url/install-win11.ps1\" -OutFile \"$env:TEMP\install-win11.ps1\"; ^
     Invoke-WebRequest -UseBasicParsing -Uri \"$url/install-win11.ps1.sha256\" -OutFile \"$env:TEMP\install-win11.ps1.sha256\"; ^
     $expected = ((Get-Content \"$env:TEMP\install-win11.ps1.sha256\" -Raw).Trim() -split '\s+')[0].ToLower(); ^
     $actual = (Get-FileHash -Path \"$env:TEMP\install-win11.ps1\" -Algorithm SHA256).Hash.ToLower(); ^
     if ($actual -ne $expected) { throw 'SHA-256 mismatch on downloaded install-win11.ps1' }; ^
     & \"$env:TEMP\install-win11.ps1\"; ^
   }"
