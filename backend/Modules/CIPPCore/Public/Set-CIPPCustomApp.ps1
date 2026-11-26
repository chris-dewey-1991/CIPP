function Set-CIPPCustomApp {
    <#
    .SYNOPSIS
        Publishes or updates a custom app template in a tenant's organisation app catalog
    .DESCRIPTION
        Looks the app up by its manifest id. A missing app is published, an older version is updated to the
        template's version, and an equal or newer version is left alone. Returns one { resultText; state } result.
    .FUNCTIONALITY
        Internal
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$TenantFilter,
        [Parameter(Mandatory)]$Template,
        $Existing,
        [switch]$ExistingRead,
        $Headers,
        [string]$APIName = 'Deploy Custom App'
    )

    $AppName = "$($Template.AppName ?? $Template.TemplateName)"
    try {
        $ManifestId = [guid]::Empty
        if (-not [guid]::TryParse("$($Template.ManifestId)", [ref]$ManifestId)) { throw [System.ArgumentException]::new("Template '$($Template.TemplateName)' has no valid app id. Upload the app package again.") }
        if (-not $Template.Package) { throw [System.ArgumentException]::new("Template '$($Template.TemplateName)' has no app package. Upload the app package again.") }

        if (-not $ExistingRead) {
            $Existing = $null
            foreach ($App in (New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/appCatalogs/teamsApps?`$filter=externalId eq '$ManifestId'&`$expand=appDefinitions" -tenantid $TenantFilter)) {
                if ($App) { $Existing = $App; break }
            }
        }

        $Bytes = [Convert]::FromBase64String("$($Template.Package)")
        if (-not $Existing) {
            $null = New-GraphPOSTRequest -uri 'https://graph.microsoft.com/v1.0/appCatalogs/teamsApps' -tenantid $TenantFilter -type POST -body $Bytes -contentType 'application/zip'
            $Message = "Added $AppName $($Template.Version) to the app catalog"
            Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Message -sev Info
            return @{ resultText = "$($Message): $TenantFilter"; state = 'success' }
        }

        $InstalledVersion = Get-CIPPCustomAppVersion -App $Existing
        $Comparison = Compare-CIPPCustomAppVersion -Installed $InstalledVersion -Template "$($Template.Version)"
        if ($Comparison -ge 0) {
            $Detail = if ($Comparison -eq 0) { "is already on version $InstalledVersion" } else { "has a newer version ($InstalledVersion) than the template ($($Template.Version)), so it was left as it is" }
            return @{ resultText = "$AppName $($Detail): $TenantFilter"; state = 'success' }
        }

        $null = New-GraphPOSTRequest -uri "https://graph.microsoft.com/v1.0/appCatalogs/teamsApps/$($Existing.id)/appDefinitions" -tenantid $TenantFilter -type POST -body $Bytes -contentType 'application/zip'
        $Message = "Updated $AppName from $InstalledVersion to $($Template.Version) in the app catalog"
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Message -sev Info
        return @{ resultText = "$($Message): $TenantFilter"; state = 'success' }
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Message = "Failed to deploy $AppName to the app catalog: $($ErrorMessage.NormalizedError)"
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Message -sev Error -LogData $ErrorMessage
        return @{ resultText = "$($Message): $TenantFilter"; state = 'error' }
    }
}
