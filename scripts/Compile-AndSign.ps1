[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceFile,

    [Parameter(Mandatory = $true)]
    [string]$OutputExe,

    [Parameter(Mandatory = $true)]
    [string]$CertThumbprint,

    [string]$TimestampUrl = 'http://timestamp.digicert.com',

    [string]$SummaryPath = 'build-summary-andsign.json',

    [switch]$VerboseMode
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($VerboseMode) {
    $VerbosePreference = 'Continue'
}

$summary = [ordered]@{
    script           = 'Compile-AndSign'
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
    Write-Host "[Compile-AndSign] Compiling artifact: $OutputExe"
    $compileArgs = @('/target:exe', "/out:$OutputExe", $SourceFile)
    $compileResult = Invoke-ExternalTool -FilePath 'csc' -ArgumentList $compileArgs -StepName 'compile-csc' -Critical

    if ($compileResult.ExitCode -ne 0) {
        throw "csc failed with exit code $($compileResult.ExitCode)."
    }

    $summary.artifacts += [ordered]@{
        path   = $OutputExe
        type   = 'executable'
        status = 'built'
    }

    Write-Host "[Compile-AndSign] Signing artifact: $OutputExe"
    $signArgs = @('sign', '/sha1', $CertThumbprint, '/fd', 'SHA256', '/tr', $TimestampUrl, '/td', 'SHA256', $OutputExe)
    $signResult = Invoke-ExternalTool -FilePath 'signtool' -ArgumentList $signArgs -StepName 'sign-signtool' -Critical

    if ($signResult.ExitCode -ne 0) {
        throw "signtool sign failed with exit code $($signResult.ExitCode)."
    }

    $summary.signatureResults += [ordered]@{
        artifact = $OutputExe
        action   = 'sign'
        status   = 'signed'
        exitCode = $signResult.ExitCode
    }

    Write-Host "[Compile-AndSign] Verifying signature: $OutputExe"
    $verifyArgs = @('verify', '/pa', $OutputExe)
    $verifyResult = Invoke-ExternalTool -FilePath 'signtool' -ArgumentList $verifyArgs -StepName 'verify-signtool' -Critical

    if ($verifyResult.ExitCode -ne 0) {
        throw "signtool verify failed with exit code $($verifyResult.ExitCode)."
    }

    $summary.signatureResults += [ordered]@{
        artifact = $OutputExe
        action   = 'verify'
        status   = 'verified'
        exitCode = $verifyResult.ExitCode
    }

    $summary.status = 'succeeded'
    Write-Host '[Compile-AndSign] Build succeeded.'
}
catch {
    $summary.status = 'failed'
    Write-Error "[Compile-AndSign] Critical failure: $($_.Exception.Message)" -ErrorAction Continue
    Write-BuildSummary
    exit 1
}

Write-BuildSummary
