param([string]$ServiceName = 'StormRaven')

Write-Host "Applying recovery policy to service: $ServiceName"
sc.exe failure $ServiceName reset= 86400 actions= restart/5000/restart/5000/restart/5000 | Out-Null
sc.exe failureflag $ServiceName 1 | Out-Null
Write-Host "Recovery policy applied."