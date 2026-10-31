function Service-WindowsImage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ImagePath,

        [Parameter(Mandatory)]
        [string]$MountPath,

        [Parameter(Mandatory)]
        [int]$Index,

        [Parameter(Mandatory)]
        [scriptblock]$ServiceAction
    )

    $mountSucceeded = $false
    $saveChanges = $false

    try {
        Write-Verbose "Mounting Windows image '$ImagePath' (index $Index) to '$MountPath'."
        Mount-WindowsImage -ImagePath $ImagePath -Index $Index -Path $MountPath -ErrorAction Stop
        $mountSucceeded = $true

        $softwareHiveName = 'HKLM\StormRaven_SOFTWARE'
        $systemHiveName = 'HKLM\StormRaven_SYSTEM'
        $softwareHivePath = Join-Path -Path $MountPath -ChildPath 'Windows\\System32\\config\\SOFTWARE'
        $systemHivePath = Join-Path -Path $MountPath -ChildPath 'Windows\\System32\\config\\SYSTEM'

        $softwareLoaded = $false
        $systemLoaded = $false

        try {
            Write-Verbose "Loading SOFTWARE hive from '$softwareHivePath'."
            & reg.exe load $softwareHiveName $softwareHivePath | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to load SOFTWARE hive at '$softwareHivePath' (exit code $LASTEXITCODE)."
            }
            $softwareLoaded = $true

            Write-Verbose "Loading SYSTEM hive from '$systemHivePath'."
            & reg.exe load $systemHiveName $systemHivePath | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to load SYSTEM hive at '$systemHivePath' (exit code $LASTEXITCODE)."
            }
            $systemLoaded = $true

            Write-Verbose 'Executing service action against loaded hives.'
            & $ServiceAction -SoftwareHiveRoot $softwareHiveName -SystemHiveRoot $systemHiveName

            $saveChanges = $true
        }
        finally {
            if ($systemLoaded) {
                Write-Verbose "Unloading SYSTEM hive '$systemHiveName'."
                & reg.exe unload $systemHiveName | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "Failed to unload SYSTEM hive '$systemHiveName' (exit code $LASTEXITCODE). Manual stale-hive remediation may be required."
                }
            }

            if ($softwareLoaded) {
                Write-Verbose "Unloading SOFTWARE hive '$softwareHiveName'."
                & reg.exe unload $softwareHiveName | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "Failed to unload SOFTWARE hive '$softwareHiveName' (exit code $LASTEXITCODE). Manual stale-hive remediation may be required."
                }
            }
        }
    }
    catch {
        $saveChanges = $false
        throw
    }
    finally {
        if ($mountSucceeded) {
            if ($saveChanges) {
                Write-Verbose "Dismounting image '$MountPath' and saving changes."
                Dismount-WindowsImage -Path $MountPath -Save -ErrorAction Stop
            }
            else {
                Write-Verbose "Dismounting image '$MountPath' and discarding changes."
                Dismount-WindowsImage -Path $MountPath -Discard -ErrorAction Stop
            }
        }
    }
}
