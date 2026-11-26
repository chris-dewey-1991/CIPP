function Invoke-ListCustomApps {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        Tenant.Application.Read
    .SYNOPSIS
        List custom apps in a tenant's app catalog
    .DESCRIPTION
        Lists the custom (organisation) apps uploaded to the tenant's Teams and Microsoft 365 app catalog, with their
        version and, where a custom app template exists for the app, whether the tenant is on the template's version.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $TenantFilter = $Request.Query.tenantFilter

    try {
        $Apps = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/appCatalogs/teamsApps?`$filter=distributionMethod eq 'organization'&`$expand=appDefinitions" -tenantid $TenantFilter

        $Table = Get-CIPPTable -TableName 'templates'
        $TemplatesByManifestId = @{}
        foreach ($Row in (Get-CIPPAzDataTableEntity @Table -Filter "PartitionKey eq 'CustomAppTemplate'" -Property PartitionKey, RowKey, JSON)) {
            $Template = [CIPP.CippJson]::ConvertFromJson($Row.JSON, @('GUID', 'TemplateName', 'ManifestId', 'Version'))
            if ($Template.ManifestId) { $TemplatesByManifestId["$($Template.ManifestId)".ToLowerInvariant()] = $Template }
        }

        $Body = foreach ($App in $Apps) {
            if (-not $App) { continue }
            $Version = Get-CIPPCustomAppVersion -App $App
            $Latest = $null
            foreach ($Definition in $App.appDefinitions) { if ("$($Definition.version)" -eq $Version) { $Latest = $Definition } }
            $Template = $TemplatesByManifestId["$($App.externalId)".ToLowerInvariant()]
            $TemplateStatus = if (-not $Template) { 'No template' } else {
                switch (Compare-CIPPCustomAppVersion -Installed $Version -Template "$($Template.Version)") {
                    -1 { 'Update available' }
                    0 { 'Up to date' }
                    1 { 'Newer than template' }
                }
            }
            [PSCustomObject]@{
                id                   = $App.id
                externalId           = $App.externalId
                displayName          = $App.displayName
                version              = $Version
                shortDescription     = $Latest.shortDescription
                publishingState      = $Latest.publishingState
                lastModifiedDateTime = $Latest.lastModifiedDateTime
                templateId           = $Template.GUID
                templateName         = $Template.TemplateName
                templateVersion      = $Template.Version
                templateStatus       = $TemplateStatus
            }
        }
        $Body = @($Body)
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $ErrorMessage = Get-CippException -Exception $_
        $Body = @{ Results = "Failed to list custom apps: $($ErrorMessage.NormalizedError)" }
        $StatusCode = Get-CippErrorStatusCode -ErrorRecord $_
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
