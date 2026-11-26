function Set-CIPPDBCacheCustomApps {
    <#
    .SYNOPSIS
        Caches the custom (organisation) apps in a tenant's Teams and Microsoft 365 app catalog
    .FUNCTIONALITY
        Internal
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TenantFilter,

        [string]$QueueId
    )

    try {
        Write-LogMessage -API 'CIPPDBCache' -tenant $TenantFilter -message 'Caching custom apps' -sev Debug
        New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/appCatalogs/teamsApps?`$filter=distributionMethod eq 'organization'&`$expand=appDefinitions" -tenantid $TenantFilter |
            Add-CIPPDbItem -TenantFilter $TenantFilter -Type 'CustomApps' -AddCount
    } catch {
        Write-LogMessage -API 'CIPPDBCache' -tenant $TenantFilter -message "Failed to cache custom apps: $($_.Exception.Message)" -sev Error -LogData (Get-CippException -Exception $_)
    }
}
