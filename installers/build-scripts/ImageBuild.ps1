Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-CodeSigningPassword {
    [CmdletBinding()]
    param(
        [string]$EnvironmentVariableName = 'STORMRAVEN_CODESIGN_PASSWORD',
        [scriptblock]$SecretProvider
    )

    if ($SecretProvider) {
        $secret = & $SecretProvider
        if ([string]::IsNullOrWhiteSpace($secret)) {
            throw 'Secret provider returned an empty code-signing password.'
        }

        return $secret
    }

    $passwordFromEnvironment = [Environment]::GetEnvironmentVariable($EnvironmentVariableName)
    if ([string]::IsNullOrWhiteSpace($passwordFromEnvironment)) {
        throw "Required code-signing password is unavailable. Set $EnvironmentVariableName or pass -SecretProvider."
    }

    return $passwordFromEnvironment
}

function Write-AuditEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        [string]$AuditLogPath = 'logs/security-audit.log'
    )

    $timestamp = [DateTimeOffset]::UtcNow.ToString('o')
    $entry = "$timestamp`t$Message"

    $auditDirectory = Split-Path -Parent $AuditLogPath
    if (-not [string]::IsNullOrWhiteSpace($auditDirectory) -and -not (Test-Path -LiteralPath $auditDirectory)) {
        New-Item -ItemType Directory -Path $auditDirectory -Force | Out-Null
    }

    Add-Content -LiteralPath $AuditLogPath -Value $entry
}

function Compile-AndSign {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CertificatePath,
        [string]$PasswordEnvironmentVariableName = 'STORMRAVEN_CODESIGN_PASSWORD',
        [scriptblock]$SecretProvider
    )

    $certificatePassword = Get-CodeSigningPassword -EnvironmentVariableName $PasswordEnvironmentVariableName -SecretProvider $SecretProvider

    # Existing compile logic intentionally omitted.
    # Any use of certificatePassword should convert it to SecureString at point of use.
    $securePassword = ConvertTo-SecureString -String $certificatePassword -AsPlainText -Force

    Write-Verbose "Loaded code-signing secret from secure channel for certificate: $CertificatePath"

    [PSCustomObject]@{
        CertificatePath = $CertificatePath
        PasswordLoaded  = $null -ne $securePassword
    }
}

function Add-EnterpriseRootCertificate {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)]
        [string]$CertificatePath,
        [Parameter(Mandatory)]
        [string[]]$AllowedThumbprints,
        [Parameter(Mandatory)]
        [switch]$OperatorConfirmed,
        [string]$AuditLogPath = 'logs/security-audit.log'
    )

    if (-not $OperatorConfirmed.IsPresent) {
        throw 'Root trust provisioning requires explicit operator confirmation via -OperatorConfirmed.'
    }

    if (-not (Test-Path -LiteralPath $CertificatePath)) {
        throw "Certificate file does not exist: $CertificatePath"
    }

    $certificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertificatePath)
    $thumbprint = $certificate.Thumbprint.ToUpperInvariant()

    $normalizedAllowlist = $AllowedThumbprints | ForEach-Object { $_.ToUpperInvariant() }
    if ($thumbprint -notin $normalizedAllowlist) {
        throw "Thumbprint $thumbprint is not allowlisted for root trust provisioning."
    }

    if ($PSCmdlet.ShouldProcess('LocalMachine\\Root', "Import certificate $thumbprint")) {
        Import-Certificate -FilePath $CertificatePath -CertStoreLocation 'Cert:\\LocalMachine\\Root' | Out-Null
        Write-AuditEvent -Message "Enterprise root certificate imported. Thumbprint=$thumbprint Path=$CertificatePath" -AuditLogPath $AuditLogPath
    }
}

function Service-WindowsImage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ImagePath,
        [switch]$EnableEnterpriseRootProvisioning,
        [string]$EnterpriseRootCertificatePath,
        [string[]]$AllowedRootThumbprints,
        [switch]$OperatorConfirmed,
        [string]$AuditLogPath = 'logs/security-audit.log'
    )

    Write-Verbose "Servicing Windows image at $ImagePath"

    # Existing image servicing logic intentionally omitted.

    if ($EnableEnterpriseRootProvisioning.IsPresent) {
        if ([string]::IsNullOrWhiteSpace($EnterpriseRootCertificatePath)) {
            throw 'Enterprise root provisioning requires -EnterpriseRootCertificatePath.'
        }

        if (-not $AllowedRootThumbprints -or $AllowedRootThumbprints.Count -eq 0) {
            throw 'Enterprise root provisioning requires at least one value in -AllowedRootThumbprints.'
        }

        Add-EnterpriseRootCertificate -CertificatePath $EnterpriseRootCertificatePath `
            -AllowedThumbprints $AllowedRootThumbprints `
            -OperatorConfirmed:$OperatorConfirmed `
            -AuditLogPath $AuditLogPath
    }

    [PSCustomObject]@{
        ImagePath                         = $ImagePath
        EnterpriseRootProvisioningEnabled = $EnableEnterpriseRootProvisioning.IsPresent
    }
}
