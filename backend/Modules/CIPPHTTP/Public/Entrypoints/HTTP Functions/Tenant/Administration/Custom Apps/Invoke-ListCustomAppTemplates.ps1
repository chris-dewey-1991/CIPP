function Invoke-ListCustomAppTemplates {
    <#
    .FUNCTIONALITY
        Entrypoint,AnyTenant
    .ROLE
        Tenant.Application.Read
    .SYNOPSIS
        List custom app templates
    .DESCRIPTION
        Lists the saved custom app templates (uploaded Teams and Microsoft 365 app packages) with their app name, app id
        and version. The package itself is not returned.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    try {
        $Table = Get-CIPPTable -TableName 'templates'
        $Fields = @('TemplateName', 'AppName', 'Description', 'Developer', 'ManifestId', 'Version', 'FileName', 'PackageSize', 'CreatedBy', 'CreatedOn', 'UpdatedBy', 'UpdatedOn')
        $Body = foreach ($Row in (Get-CIPPAzDataTableEntity @Table -Filter "PartitionKey eq 'CustomAppTemplate'" -Property PartitionKey, RowKey, JSON)) {
            $Template = [CIPP.CippJson]::ConvertFromJson($Row.JSON, $Fields)
            [PSCustomObject]@{
                GUID         = $Row.RowKey
                TemplateName = $Template.TemplateName
                AppName      = $Template.AppName
                Description  = $Template.Description
                Developer    = $Template.Developer
                ManifestId   = $Template.ManifestId
                Version      = $Template.Version
                FileName     = $Template.FileName
                PackageSize  = $Template.PackageSize
                CreatedBy    = $Template.CreatedBy
                CreatedOn    = $Template.CreatedOn
                UpdatedBy    = $Template.UpdatedBy
                UpdatedOn    = $Template.UpdatedOn
            }
        }
        $Body = @($Body)
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $Body = @{ Results = "Failed to list custom app templates: $($_.Exception.Message)" }
        $StatusCode = Get-CippErrorStatusCode -ErrorRecord $_
    }

    return ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $Body
        })
}
