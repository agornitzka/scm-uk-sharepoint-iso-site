<#
One-time setup: registers the Entra app registration used for unattended,
app-only provisioning of the UK ISO PoC site (see docs/app-registration.md
for why app-only + certificate auth is used, and the exact permissions).

Run this once, interactively, by an Entra account that can create app
registrations (Application Administrator / Cloud Application Administrator /
Global Administrator). It does NOT grant admin consent — that is always a
separate, manual step by a Global/Privileged Role Administrator; see
docs/app-registration.md.

Requires: PnP.PowerShell module (Install-Module PnP.PowerShell -Scope CurrentUser)
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Tenant,                                   # e.g. "scanmetals.onmicrosoft.com"

    [string]$ApplicationName = 'Zentura-ISOPoC-Provisioning',

    [string]$OutPath = (Join-Path $PSScriptRoot 'secrets'),

    [SecureString]$CertificatePassword,

    [int]$ValidYears = 2,

    [switch]$DeviceLogin                                # use if the machine can't open a browser
)

if (-not (Get-Module -ListAvailable -Name PnP.PowerShell)) {
    throw "PnP.PowerShell module not found. Install it first: Install-Module PnP.PowerShell -Scope CurrentUser"
}
Import-Module PnP.PowerShell

if (-not (Test-Path $OutPath)) {
    New-Item -Path $OutPath -ItemType Directory | Out-Null
}

if (-not $CertificatePassword) {
    $CertificatePassword = Read-Host -AsSecureString -Prompt 'Set a password for the exported .pfx'
}

$registerParams = @{
    ApplicationName                   = $ApplicationName
    Tenant                            = $Tenant
    OutPath                           = $OutPath
    CertificatePassword               = $CertificatePassword
    ValidYears                        = $ValidYears
    GraphApplicationPermissions       = @('Group.Read.All')
    SharePointApplicationPermissions  = @('Sites.FullControl.All')
    Store                             = 'CurrentUser'   # Windows only; imports the cert into the local cert store too
}
if ($DeviceLogin) {
    $registerParams['DeviceLogin'] = $true
}

Write-Host "Registering Entra app '$ApplicationName' in tenant '$Tenant'..."
$app = Register-PnPAzureADApp @registerParams

Write-Host ""
Write-Host "App registered. Record these values — they go into Provision.config.psd1:"
Write-Host "  TenantId              : $Tenant"
Write-Host "  ClientId              : $($app.'AzureAppId/ClientId')"
Write-Host "  CertificateThumbprint : $($app.'Certificate Thumbprint')"
Write-Host ""
Write-Host "Certificate files written to: $OutPath"
Write-Host "  - keep the .pfx and its password secret; both are excluded from git via .gitignore"
Write-Host ""
Write-Host "NEXT STEP (manual, required): grant admin consent for the app's API permissions." -ForegroundColor Yellow
Write-Host "  Entra admin center -> Identity -> Applications -> App registrations -> $ApplicationName" -ForegroundColor Yellow
Write-Host "  -> API permissions -> Grant admin consent for <tenant>." -ForegroundColor Yellow
Write-Host "  Provisioning will fail with 401/403 until this is done. See docs/app-registration.md." -ForegroundColor Yellow

# Write the values straight into Provision.config.psd1 so the next script just works.
$configPath = Join-Path $PSScriptRoot 'Provision.config.psd1'
if (Test-Path $configPath) {
    $raw = Get-Content $configPath -Raw
    $raw = $raw -replace "TenantId\s*=\s*''", "TenantId              = '$Tenant'"
    $raw = $raw -replace "ClientId\s*=\s*''", "ClientId              = '$($app.'AzureAppId/ClientId')'"
    $raw = $raw -replace "CertificateThumbprint\s*=\s*''", "CertificateThumbprint = '$($app.'Certificate Thumbprint')'"
    Set-Content -Path $configPath -Value $raw
    Write-Host "Updated $configPath with TenantId, ClientId, and CertificateThumbprint."
}
