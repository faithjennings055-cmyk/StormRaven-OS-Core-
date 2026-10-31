[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string[]]$EntryScripts,

    [string]$OutputDir = 'dist',

    [string]$SummaryPath = 'build-summary-pythonmicroservices.json',

    [switch]$VerboseMode
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($VerboseMode) {
    $VerbosePreference = 'Continue'
}

$summary = [ordered]@{
    script           = 'Compile-PythonMicroservices'
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
    New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null

    foreach ($entryScript in $EntryScripts) {
        $serviceName = [System.IO.Path]::GetFileNameWithoutExtension($entryScript)
        Write-Host "[Compile-PythonMicroservices] Building service: $serviceName"

        $args = @('--noconfirm', '--onefile', '--distpath', $OutputDir, $entryScript)
        $result = Invoke-ExternalTool -FilePath 'pyinstaller' -ArgumentList $args -StepName "pyinstaller-$serviceName" -Critical

        if ($result.ExitCode -ne 0) {
            throw "pyinstaller failed for '$entryScript' with exit code $($result.ExitCode)."
        }

        $artifactPath = Join-Path -Path $OutputDir -ChildPath $serviceName
        $summary.artifacts += [ordered]@{
            service = $serviceName
            path    = $artifactPath
            type    = 'python-microservice-binary'
            status  = 'built'
        }

        Write-Host "[Compile-PythonMicroservices] Built artifact: $artifactPath"
    }

    $summary.status = 'succeeded'
    Write-Host '[Compile-PythonMicroservices] Build succeeded.'
}
catch {
    $summary.status = 'failed'
    Write-Error "[Compile-PythonMicroservices] Critical failure: $($_.Exception.Message)"
    Write-BuildSummary
    exit 1
}

Write-BuildSummary
