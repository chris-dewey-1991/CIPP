function Invoke-ExecDeployCustomApp {
    <#
    .FUNCTIONALITY
        Entrypoint,AnyTenant
    .ROLE
        Tenant.Application.ReadWrite
    .SYNOPSIS
        Deploy a custom app template to tenant app catalogs
    .DESCRIPTION
        Publishes a custom app template to each selected tenant's Teams and Microsoft 365 app catalog, or updates the
        app there when the tenant has an older version.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    # The custom app template to deploy
    $TemplateId = "$($Request.Body.TemplateId.value ?? $Request.Body.TemplateId)"
    # Tenants to deploy to, as tenant picker values (default domain names or AllTenants)
    $SelectedTenants = foreach ($Tenant in $Request.Body.selectedTenants) { "$($Tenant.value ?? $Tenant)" }

    $ParsedId = [guid]::Empty
    if (-not [guid]::TryParse($TemplateId, [ref]$ParsedId)) {
        return ([HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'TemplateId is required.' } })
    }
    if (-not $SelectedTenants) {
        return ([HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'Select at least one tenant.' } })
    }

    try {
        $Table = Get-CIPPTable -TableName 'templates'
        $Row = Get-CIPPAzDataTableEntity @Table -Filter "PartitionKey eq 'CustomAppTemplate' and RowKey eq '$ParsedId'" -Property PartitionKey, RowKey, JSON
        if (-not $Row) { throw [System.Management.Automation.ItemNotFoundException]::new('That custom app template no longer exists.') }
        $Template = [CIPP.CippJson]::ConvertFromJson($Row.JSON, $null)

        if ('AllTenants' -in $SelectedTenants) { $SelectedTenants = (Get-Tenants).defaultDomainName }
        # Tenant scope: a scoped role must not reach tenants outside its allowed set through selectedTenants/AllTenants.
        $AllowedTenants = Test-CippAccess -Request $Request -TenantList
        if ('AllTenants' -notin $AllowedTenants) {
            $AllowedDomains = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($Tenant in (Get-Tenants -IncludeErrors)) { if ($Tenant.customerId -in $AllowedTenants) { [void]$AllowedDomains.Add($Tenant.defaultDomainName) } }
            $SelectedTenants = foreach ($Tenant in $SelectedTenants) { if ($AllowedDomains.Contains($Tenant)) { $Tenant } }
            if (-not $SelectedTenants) {
                return ([HttpResponseContext]@{ StatusCode = [HttpStatusCode]::Forbidden; Body = @{ Results = 'You do not have access to the selected tenants.' } })
            }
        }

        $Results = foreach ($TenantFilter in @($SelectedTenants)) {
            Set-CIPPCustomApp -TenantFilter $TenantFilter -Template $Template -Headers $Headers -APIName $APIName
        }
        $Results = @($Results)
        $Failed = @($Results.Where({ $_.state -eq 'error' })).Count
        $StatusCode = Get-CippBulkStatusCode -Total $Results.Count -Failed $Failed
        $Body = @{ Results = $Results }
    } catch {
        $Body = @{ Results = "Failed to deploy the custom app: $($_.Exception.Message)" }
        $StatusCode = Get-CippErrorStatusCode -ErrorRecord $_
    }

    return ([HttpResponseContext]@{ StatusCode = $StatusCode; Body = $Body })
}
