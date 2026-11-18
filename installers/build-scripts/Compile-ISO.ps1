[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceDirectory,

    [Parameter(Mandatory = $true)]
    [string]$OutputIso,

    [string]$BootImagePath,

    [string]$VolumeLabel = 'StormRavenOS',

    [string]$SummaryPath = 'build-summary-iso.json',

    [switch]$VerboseMode
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($VerboseMode) {
    $VerbosePreference = 'Continue'
}

$summary = [ordered]@{
    script           = 'Compile-ISO'
    startTimeUtc     = (Get-Date).ToUniversalTime().ToString('o')
    endTimeUtc       = $null
    status           = 'running'
    steps            = @()
    artifacts        = @()
    signatureResults = @()
}

function Add-StepResult {
    param(
        [string]$Name,
        [string]$Status,
        [int]$ExitCode,
        [string]$Command,
        [string]$StdOut,
        [string]$StdErr
    )

    $script:summary.steps += [ordered]@{
        name     = $Name
        status   = $Status
        exitCode = $ExitCode
        command  = $Command
        stdout   = $StdOut
        stderr   = $StdErr
    }
}

function Write-BuildSummary {
    $summary.endTimeUtc = (Get-Date).ToUniversalTime().ToString('o')
    $summary | ConvertTo-Json -Depth 8 | Set-Content -Path $SummaryPath -Encoding UTF8
}

function Invoke-ExternalTool {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string[]]$ArgumentList,

        [Parameter(Mandatory = $true)]
        [string]$StepName,

        [switch]$Critical
    )

    $stdoutFile = [System.IO.Path]::GetTempFileName()
    $stderrFile = [System.IO.Path]::GetTempFileName()

    try {
        Write-Verbose ("Running {0}: {1} {2}" -f $StepName, $FilePath, ($ArgumentList -join ' '))
        $process = Start-Process -FilePath $FilePath -ArgumentList $ArgumentList -NoNewWindow -Wait -PassThru -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile

        $stdout = (Get-Content -Path $stdoutFile -Raw -ErrorAction SilentlyContinue)
        $stderr = (Get-Content -Path $stderrFile -Raw -ErrorAction SilentlyContinue)

        $status = if ($process.ExitCode -eq 0) { 'succeeded' } else { 'failed' }
        Add-StepResult -Name $StepName -Status $status -ExitCode $process.ExitCode -Command ("{0} {1}" -f $FilePath, ($ArgumentList -join ' ')) -StdOut $stdout -StdErr $stderr

        if ($Critical -and $process.ExitCode -ne 0) {
            throw "Step '$StepName' failed with exit code $($process.ExitCode)."
        }

        return [ordered]@{
            ExitCode = $process.ExitCode
            StdOut   = $stdout
            StdErr   = $stderr
        }
    }
    finally {
        Remove-Item -Path $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
    }
}

try {
    Write-Host "[Compile-ISO] Building ISO artifact: $OutputIso"

    $oscdimgArgs = @('-l', $VolumeLabel)
    if ($BootImagePath) {
        $oscdimgArgs += @('-b', $BootImagePath)
    }
    $oscdimgArgs += @($SourceDirectory, $OutputIso)

    $result = Invoke-ExternalTool -FilePath 'oscdimg' -ArgumentList $oscdimgArgs -StepName 'build-iso' -Critical

    if ($result.ExitCode -ne 0) {
        throw "oscdimg failed with exit code $($result.ExitCode)."
    }

    $summary.artifacts += [ordered]@{
        path   = $OutputIso
        type   = 'iso'
        status = 'built'
    }

    $summary.status = 'succeeded'
    Write-Host '[Compile-ISO] Build succeeded.'
}
catch {
    $summary.status = 'failed'
    Write-Error "[Compile-ISO] Critical failure: $($_.Exception.Message)"
    Write-BuildSummary
    exit 1
}

Write-BuildSummary
