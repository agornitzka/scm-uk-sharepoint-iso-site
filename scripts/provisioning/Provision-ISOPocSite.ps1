<#
Provisions the UK ISO PoC SharePoint site: site columns, the "Controlled
Document" content type, one library per configured process area plus the
shared Obsolete library, versioning/approval settings, permissions by Entra
security group, and a default view.

Connects app-only via certificate (no interactive login) using the app
registration created by Register-ISOPocAppRegistration.ps1. Run this only
after admin consent has been granted on that app registration — see
docs/app-registration.md.

Config: edit Provision.config.psd1 (site URL, process areas, security group
object IDs) before running. Safe to re-run — existing fields/content
types/libraries are left as-is rather than duplicated.

Requires: PnP.PowerShell module.
#>
[CmdletBinding()]
param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot 'Provision.config.psd1')
)

$ErrorActionPreference = 'Stop'
Import-Module PnP.PowerShell

$cfg = Import-PowerShellDataFile -Path $ConfigPath
foreach ($required in 'TenantId', 'ClientId', 'CertificateThumbprint', 'SiteUrl') {
    if ([string]::IsNullOrWhiteSpace($cfg[$required])) {
        throw "Provision.config.psd1 is missing a value for '$required'. Run Register-ISOPocAppRegistration.ps1 first, or fill it in by hand."
    }
}

Write-Host "Connecting to $($cfg.SiteUrl) (app-only, certificate)..."
Connect-PnPOnline -Url $cfg.SiteUrl -ClientId $cfg.ClientId -Tenant $cfg.TenantId -Thumbprint $cfg.CertificateThumbprint

# --- Document ID Service -----------------------------------------------
# Must be enabled before documents are created, so every ID assigned from
# here on survives the later move into the Obsolete library.
Write-Host "Enabling Document ID Service..."
Enable-PnPFeature -Identity b50e3104-6812-424f-a011-cc90e6327318 -Scope Site -Force

# --- Site columns --------------------------------------------------------
Write-Host "Creating site columns..."
$fieldGroup = $cfg.FieldGroup

$fieldsToEnsure = @(
    @{ DisplayName = 'Process area';              InternalName = 'ZProcessArea';       Type = 'Choice';   Choices = $cfg.ProcessAreas }
    @{ DisplayName = 'Document owner';             InternalName = 'ZDocOwner';          Type = 'User' }
    @{ DisplayName = 'Approver';                   InternalName = 'ZApprover';          Type = 'User' }
    @{ DisplayName = 'Document status';            InternalName = 'ZDocStatus';         Type = 'Choice';   Choices = @('Draft', 'In review', 'Approved', 'Obsolete') }
    @{ DisplayName = 'Effective date';             InternalName = 'ZEffectiveDate';     Type = 'DateTime' }
    @{ DisplayName = 'Review interval (months)';   InternalName = 'ZReviewInterval';    Type = 'Choice';   Choices = @('6', '12', '24', '36') }
    @{ DisplayName = 'Next review date';           InternalName = 'ZNextReview';        Type = 'DateTime' }
    @{ DisplayName = 'Change description';         InternalName = 'ZChangeDescription'; Type = 'Note' }
    @{ DisplayName = 'Obsolete date';              InternalName = 'ZObsoleteDate';      Type = 'DateTime' }
    @{ DisplayName = 'Obsolete reason';             InternalName = 'ZObsoleteReason';    Type = 'Text' }
)

foreach ($f in $fieldsToEnsure) {
    if (-not (Get-PnPField -Identity $f.InternalName -ErrorAction SilentlyContinue)) {
        $params = @{
            DisplayName  = $f.DisplayName
            InternalName = $f.InternalName
            Type         = $f.Type
            Group        = $fieldGroup
        }
        if ($f.Choices) { $params['Choices'] = $f.Choices }
        Add-PnPField @params | Out-Null
    }
}

# --- Content type ----------------------------------------------------------
Write-Host "Creating 'Controlled Document' content type..."
$ctName = 'Controlled Document'
$ct = Get-PnPContentType -Identity $ctName -ErrorAction SilentlyContinue
if (-not $ct) {
    $ct = Add-PnPContentType -Name $ctName -Group $fieldGroup -ParentContentType (Get-PnPContentType -Identity 'Document')
}
foreach ($f in $fieldsToEnsure) {
    Add-PnPFieldToContentType -Field $f.InternalName -ContentType $ct -ErrorAction SilentlyContinue | Out-Null
}

# --- Libraries ---------------------------------------------------------
function New-ControlledLibrary {
    param([string]$Title)

    Write-Host "Provisioning library '$Title'..."
    if (-not (Get-PnPList -Identity $Title -ErrorAction SilentlyContinue)) {
        New-PnPList -Title $Title -Template DocumentLibrary | Out-Null
    }

    Set-PnPList -Identity $Title `
        -EnableContentTypes $true `
        -EnableVersioning $true `
        -EnableMinorVersions $true `
        -EnableModeration $true `
        -DraftVersionVisibility Approver `
        -MajorVersions $cfg.MajorVersionLimit `
        -MinorVersions $cfg.MinorVersionLimit

    Add-PnPContentTypeToList -List $Title -ContentType $ctName -DefaultContentType

    # Default view: ID/status/version/next review, obsolete items hidden as a safety net.
    $viewFields = 'DocIcon', 'LinkFilename', '_dlc_DocIdUrl', 'ZDocStatus', '_UIVersionString', 'ZDocOwner', 'ZApprover', 'ZEffectiveDate', 'ZNextReview'
    $view = Get-PnPView -List $Title -Identity 'All Documents' -ErrorAction SilentlyContinue
    if ($view) {
        Set-PnPView -List $Title -Identity 'All Documents' -Fields $viewFields -Query "<Where><Neq><FieldRef Name='ZDocStatus'/><Value Type='Choice'>Obsolete</Value></Neq></Where>"
    }
}

foreach ($area in $cfg.ProcessAreas) {
    New-ControlledLibrary -Title $area
}

# Obsolete library: no content approval, read-only by default once permissions are set below.
Write-Host "Provisioning Obsolete library..."
if (-not (Get-PnPList -Identity $cfg.ObsoleteLibraryName -ErrorAction SilentlyContinue)) {
    New-PnPList -Title $cfg.ObsoleteLibraryName -Template DocumentLibrary | Out-Null
}
Set-PnPList -Identity $cfg.ObsoleteLibraryName -EnableContentTypes $true
Add-PnPContentTypeToList -List $cfg.ObsoleteLibraryName -ContentType $ctName -DefaultContentType

# --- Permissions ---------------------------------------------------------
# Inheritance is broken at the LIBRARY level only (never folder/item) — see
# docs/architecture.md §7 for why.
function Set-LibraryGroupPermissions {
    param(
        [string]$ListTitle,
        [hashtable]$RoleAssignments   # @{ GroupObjectId = 'PermissionLevel' }
    )

    Write-Host "Setting permissions on '$ListTitle'..."
    Set-PnPList -Identity $ListTitle -BreakRoleInheritance -CopyRoleAssignments:$false -ClearSubscopes

    foreach ($groupId in $RoleAssignments.Keys) {
        if ([string]::IsNullOrWhiteSpace($groupId)) { continue }
        $claim = "c:0t.c|tenant|$groupId"
        Set-PnPListPermission -Identity $ListTitle -User $claim -AddRole $RoleAssignments[$groupId]
    }
}

foreach ($area in $cfg.ProcessAreas) {
    $groups = $cfg.SecurityGroups.Areas[$area]
    Set-LibraryGroupPermissions -ListTitle $area -RoleAssignments @{
        $groups.Authors              = 'Contribute'
        $groups.Approvers            = 'Approve'
        $cfg.SecurityGroups.Readers  = 'Read'
        $cfg.SecurityGroups.Admins   = 'Full Control'
    }
}

Set-LibraryGroupPermissions -ListTitle $cfg.ObsoleteLibraryName -RoleAssignments @{
    $cfg.SecurityGroups.Readers = 'Read'
    $cfg.SecurityGroups.Admins  = 'Full Control'
}

Write-Host ""
Write-Host "Provisioning complete for $($cfg.SiteUrl)." -ForegroundColor Green
Write-Host "Remember: default inherited SharePoint groups were removed by -BreakRoleInheritance above." -ForegroundColor Green
Write-Host "Next: build the three Power Automate flows from scripts/power-automate/, then run the pilot-rollout-plan.md acceptance checklist." -ForegroundColor Green
