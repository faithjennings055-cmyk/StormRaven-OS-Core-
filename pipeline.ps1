Set-StrictMode -Version Latest

$script:PipelineState = [ordered]@{
    RunId              = $null
    RunRoot            = $null
    WorkspacePath      = $null
    OwnedMountPaths    = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    OwnedRegistryHives = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
}

function New-BuildRunId {
    [CmdletBinding()]
    param()

    return ("{0:yyyyMMddHHmmss}-{1}" -f (Get-Date), [guid]::NewGuid().ToString('N').Substring(0, 8))
}

function Get-RunScopedPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ChildPath
    )

    if ([string]::IsNullOrWhiteSpace($script:PipelineState.RunRoot)) {
        throw "Run root has not been initialized. Call Initialize-Workspace first."
    }

    return (Join-Path -Path $script:PipelineState.RunRoot -ChildPath $ChildPath)
}

function Test-SafeWorkspaceRemoval {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$ExpectedPath
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    $candidate = [System.IO.Path]::GetFullPath($Path)
    $expected = [System.IO.Path]::GetFullPath($ExpectedPath)

    if ($candidate -ne $expected) {
        return $false
    }

    $root = [System.IO.Path]::GetPathRoot($candidate)
    if ([string]::IsNullOrWhiteSpace($root) -or $candidate -eq $root) {
        return $false
    }

    if ($candidate.Length -le ($root.Length + 5)) {
        return $false
    }

    return $true
}

function Register-OwnedMount {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    [void]$script:PipelineState.OwnedMountPaths.Add([System.IO.Path]::GetFullPath($Path))
}

function Unregister-OwnedMount {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    [void]$script:PipelineState.OwnedMountPaths.Remove([System.IO.Path]::GetFullPath($Path))
}

function Register-OwnedRegistryHive {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$HiveName)

    [void]$script:PipelineState.OwnedRegistryHives.Add($HiveName)
}

function Unregister-OwnedRegistryHive {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$HiveName)

    [void]$script:PipelineState.OwnedRegistryHives.Remove($HiveName)
}

function Invoke-PreFlightValidation {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    if ([string]::IsNullOrWhiteSpace($script:PipelineState.RunRoot)) {
        throw "Pipeline state is not initialized. Call Initialize-Workspace first."
    }

    Write-Verbose "Validating run-scoped artifacts under '$($script:PipelineState.RunRoot)'"

    foreach ($mountPath in @($script:PipelineState.OwnedMountPaths)) {
        $shouldUnregisterMount = $false
        try {
            if (-not (Test-Path -LiteralPath $mountPath)) {
                Unregister-OwnedMount -Path $mountPath
                continue
            }

            if ($PSCmdlet.ShouldProcess($mountPath, 'Dismount run-owned Windows image')) {
                Dismount-WindowsImage -Path $mountPath -Discard -ErrorAction Stop
                $shouldUnregisterMount = $true
            }
        }
        finally {
            if ($shouldUnregisterMount) {
                Unregister-OwnedMount -Path $mountPath
            }
        }
    }

    foreach ($hiveName in @($script:PipelineState.OwnedRegistryHives)) {
        $shouldUnregisterHive = $false
        try {
            if ($PSCmdlet.ShouldProcess($hiveName, 'Unload run-owned registry hive')) {
                reg.exe unload "HKLM\\$hiveName" | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    throw "Failed to unload registry hive 'HKLM\\$hiveName' (reg.exe exit code: $LASTEXITCODE)."
                }

                $shouldUnregisterHive = $true
            }
        }
        finally {
            if ($shouldUnregisterHive) {
                Unregister-OwnedRegistryHive -HiveName $hiveName
            }
        }
    }

    $workspacePath = $script:PipelineState.WorkspacePath
    if (Test-SafeWorkspaceRemoval -Path $workspacePath -ExpectedPath (Get-RunScopedPath -ChildPath 'workspace')) {
        if ($PSCmdlet.ShouldProcess($workspacePath, 'Remove run-scoped workspace directory')) {
            Remove-Item -Path $workspacePath -Recurse -Force -ErrorAction Stop
        }
    }
    else {
        throw "Refusing to delete unsafe workspace path '$workspacePath'."
    }
}

function Initialize-Workspace {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$BasePath = 'C:\StormRaven\Runs',
        [string]$RunId
    )

    if ([string]::IsNullOrWhiteSpace($RunId)) {
        $RunId = New-BuildRunId
    }

    $script:PipelineState.RunId = $RunId
    $script:PipelineState.RunRoot = Join-Path -Path $BasePath -ChildPath $RunId
    $script:PipelineState.WorkspacePath = Join-Path -Path $script:PipelineState.RunRoot -ChildPath 'workspace'

    foreach ($dirName in @('temp', 'workspace', 'mounts', 'logs')) {
        $path = Join-Path -Path $script:PipelineState.RunRoot -ChildPath $dirName
        if ($PSCmdlet.ShouldProcess($path, 'Create run-scoped directory')) {
            New-Item -Path $path -ItemType Directory -Force | Out-Null
        }
    }

    [pscustomobject]@{
        RunId         = $script:PipelineState.RunId
        RunRoot       = $script:PipelineState.RunRoot
        WorkspacePath = $script:PipelineState.WorkspacePath
        TempPath      = Get-RunScopedPath -ChildPath 'temp'
        MountPath     = Get-RunScopedPath -ChildPath 'mounts'
        LogPath       = Get-RunScopedPath -ChildPath 'logs'
    }
}
