function Get-CIPPBaselineCustomAppTemplateState {
    <#
    .SYNOPSIS
        Prepare hook for CustomAppTemplate: is this instance's app in the catalog at the template's version.
    .DESCRIPTION
        One instance grades one template. The app is matched on its manifest id (externalId) in the CustomApps
        cache and is current at the template's version or newer. The template and the matched catalog entry are
        carried for the executor.
    .FUNCTIONALITY
        Internal
    #>
    [CmdletBinding()]
    param(
        $Item,
        $TenantFilter
    )

    $Reference = "$($Item.Variables.customAppTemplate.value ?? $Item.Variables.customAppTemplate)"
    $TemplateId = [guid]::Empty
    if (-not [guid]::TryParse($Reference, [ref]$TemplateId)) { return @{ Current = $null; ConfigError = $true } }

    $Table = Get-CIPPTable -tablename 'templates'
    $Entity = Get-CIPPAzDataTableEntity @Table -Filter "PartitionKey eq 'CustomAppTemplate' and RowKey eq '$TemplateId'" -Property PartitionKey, RowKey, JSON
    if (-not $Entity -or -not $Entity.JSON) { return @{ Current = $null; ConfigError = $true } }
    $Template = [CIPP.CippJson]::ConvertFromJson($Entity.JSON, $null)
    if (-not $Template.ManifestId -or -not $Template.Version -or -not $Template.Package) { return @{ Current = $null; ConfigError = $true } }

    $Apps = @(Get-CIPPBaselineCacheRows -TenantFilter $TenantFilter -Type 'CustomApps')
    if ($Apps.Count -eq 0 -and -not (Test-CIPPBaselineCacheCollected -TenantFilter $TenantFilter -Type 'CustomApps')) {
        return @{ Current = $null }
    }

    $Existing = $null
    foreach ($App in $Apps) {
        if ("$($App.externalId)" -eq "$($Template.ManifestId)") { $Existing = $App; break }
    }
    $InstalledVersion = if ($Existing) { Get-CIPPCustomAppVersion -App $Existing } else { $null }
    $Status = if (-not $Existing) { 'Not deployed' } elseif ((Compare-CIPPCustomAppVersion -Installed $InstalledVersion -Template "$($Template.Version)") -lt 0) { "Outdated ($InstalledVersion)" } else { 'Current' }

    $Current = [PSCustomObject]@{ appStatus = $Status }
    # Carried for the executor, not graded.
    $Current | Add-Member -NotePropertyMembers @{ template = $Template; existingApp = $Existing }

    @{
        Expected = [PSCustomObject]@{ appStatus = 'Current' }
        Current  = $Current
    }
}
