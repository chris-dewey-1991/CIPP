function Invoke-RemoveCustomApp {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Tenant.Application.ReadWrite
    .SYNOPSIS
        Remove a custom app from a tenant's app catalog
    .DESCRIPTION
        Deletes a custom (organisation) app from the tenant's Teams and Microsoft 365 app catalog. Users lose access
        to the app.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    $TenantFilter = $Request.Body.tenantFilter
    # The app's catalog id (id column of ListCustomApps)
    $AppId = "$($Request.Body.ID)"
    # App name, used in the result message
    $DisplayName = "$($Request.Body.displayName)"

    $ParsedId = [guid]::Empty
    if (-not [guid]::TryParse($AppId, [ref]$ParsedId)) {
        return ([HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'ID is required.' } })
    }

    try {
        $null = New-GraphPOSTRequest -uri "https://graph.microsoft.com/v1.0/appCatalogs/teamsApps/$ParsedId" -tenantid $TenantFilter -type DELETE
        $Result = "Removed $DisplayName from the app catalog."
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Result -sev Info
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Result = "Failed to remove $DisplayName from the app catalog: $($ErrorMessage.NormalizedError)"
        Write-LogMessage -headers $Headers -API $APIName -tenant $TenantFilter -message $Result -sev Error -LogData $ErrorMessage
        $StatusCode = Get-CippErrorStatusCode -ErrorRecord $_
    }

    return ([HttpResponseContext]@{ StatusCode = $StatusCode; Body = @{ Results = $Result } })
}
