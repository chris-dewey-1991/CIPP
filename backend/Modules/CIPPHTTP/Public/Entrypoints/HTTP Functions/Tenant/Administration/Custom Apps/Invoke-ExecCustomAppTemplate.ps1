function Invoke-ExecCustomAppTemplate {
    <#
    .FUNCTIONALITY
        Entrypoint,AnyTenant
    .ROLE
        Tenant.Application.ReadWrite
    .SYNOPSIS
        Save or delete a custom app template
    .DESCRIPTION
        Saves a custom app package (.zip with a manifest.json) as a template that can be deployed to tenant app
        catalogs, or deletes a template. Saving to an existing template replaces its package, which is how a new
        app version is rolled out.
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $Request.Params.CIPPEndpoint
    $Headers = $Request.Headers
    # Save or Delete
    $Action = $Request.Body.Action
    # Template to replace (Save) or remove (Delete). Leave empty to create a new template.
    $TemplateId = "$($Request.Body.TemplateId)"

    if ($Action -notin @('Save', 'Delete')) {
        return ([HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'Action must be Save or Delete.' } })
    }
    $ParsedId = [guid]::Empty
    if ($TemplateId -and -not [guid]::TryParse($TemplateId, [ref]$ParsedId)) {
        return ([HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'TemplateId is not valid.' } })
    }
    $CanWrite = if ($Action -eq 'Save') { Test-CippTemplateWriteAccess -PartitionKey 'CustomAppTemplate' -RowKey $TemplateId } else { Test-CippTemplateWriteAccess }
    if (-not $CanWrite) {
        return ([HttpResponseContext]@{ StatusCode = [HttpStatusCode]::Forbidden; Body = @{ Results = 'Roles limited to specific tenants cannot change or remove shared templates.' } })
    }

    $Table = Get-CIPPTable -TableName 'templates'

    if ($Action -eq 'Delete') {
        if (-not $TemplateId) {
            return ([HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'TemplateId is required.' } })
        }
        try {
            $Entity = Get-CIPPAzDataTableEntity @Table -Filter "PartitionKey eq 'CustomAppTemplate' and RowKey eq '$TemplateId'" -Property PartitionKey, RowKey, ETag
            if (-not $Entity) { throw [System.Management.Automation.ItemNotFoundException]::new('That custom app template no longer exists.') }
            $null = Remove-CIPPAzDataTableEntity @Table -Entity $Entity -Force
            Write-LogMessage -headers $Headers -API $APIName -message "Deleted custom app template $TemplateId" -sev Info
            $Result = 'Deleted the custom app template.'
            $StatusCode = [HttpStatusCode]::OK
        } catch {
            $Result = "Failed to delete the custom app template: $($_.Exception.Message)"
            $StatusCode = Get-CippErrorStatusCode -ErrorRecord $_
        }
        return ([HttpResponseContext]@{ StatusCode = $StatusCode; Body = @{ Results = $Result } })
    }

    # The app package (.zip) as base64, with or without a data: URL prefix
    $Package = "$($Request.Body.Package)"
    if (-not $Package) {
        return ([HttpResponseContext]@{ StatusCode = [HttpStatusCode]::BadRequest; Body = @{ Results = 'Package is required: upload the app package (.zip).' } })
    }

    try {
        $Comma = $Package.IndexOf(',')
        if ($Package.StartsWith('data:') -and $Comma -gt 0) { $Package = $Package.Substring($Comma + 1) }
        try { $Bytes = [Convert]::FromBase64String($Package) } catch { throw [System.ArgumentException]::new('The uploaded file could not be read. Upload the app package (.zip) again.') }
        if ($Bytes.Length -gt 5MB) { throw [System.ArgumentException]::new('The app package is larger than 5 MB. App packages normally contain only the manifest and two icons.') }

        Add-Type -AssemblyName System.IO.Compression
        $Manifest = $null
        $Stream = [System.IO.MemoryStream]::new($Bytes)
        try {
            try { $Zip = [System.IO.Compression.ZipArchive]::new($Stream, [System.IO.Compression.ZipArchiveMode]::Read) } catch { throw [System.ArgumentException]::new('The uploaded file is not a .zip app package.') }
            foreach ($Entry in $Zip.Entries) {
                if ($Entry.FullName -ne 'manifest.json' -and $Entry.FullName -ne 'Manifest.json') { continue }
                $Reader = [System.IO.StreamReader]::new($Entry.Open())
                try { $Manifest = $Reader.ReadToEnd() | ConvertFrom-Json -ErrorAction Stop } catch { throw [System.ArgumentException]::new("The package's manifest.json is not valid JSON.") } finally { $Reader.Dispose() }
                break
            }
            $Zip.Dispose()
        } finally { $Stream.Dispose() }

        if (-not $Manifest) { throw [System.ArgumentException]::new('The package has no manifest.json at its top level. Zip the manifest and icons themselves, not the folder that contains them.') }
        $ManifestId = [guid]::Empty
        if (-not [guid]::TryParse("$($Manifest.id)", [ref]$ManifestId)) { throw [System.ArgumentException]::new("The package's manifest.json has no valid app id.") }
        if (-not $Manifest.version) { throw [System.ArgumentException]::new("The package's manifest.json has no version.") }
        $AppName = "$($Manifest.name.short ?? $Manifest.name)"

        $Existing = $null
        foreach ($Row in (Get-CIPPAzDataTableEntity @Table -Filter "PartitionKey eq 'CustomAppTemplate'" -Property PartitionKey, RowKey, JSON)) {
            $Stored = [CIPP.CippJson]::ConvertFromJson($Row.JSON, @('TemplateName', 'ManifestId', 'CreatedBy', 'CreatedOn'))
            if ($Row.RowKey -eq $TemplateId) { $Existing = $Stored; continue }
            if ("$($Stored.ManifestId)" -eq "$ManifestId") {
                throw [System.ArgumentException]::new("The template '$($Stored.TemplateName)' already holds this app. Upload the new version to that template instead.")
            }
        }
        if ($TemplateId -and -not $Existing) { throw [System.Management.Automation.ItemNotFoundException]::new('That custom app template no longer exists.') }

        $User = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Headers.'x-ms-client-principal')) | ConvertFrom-Json
        $UserName = $User.UserDetails ?? 'CIPP-API'
        $Now = (Get-Date).ToUniversalTime().ToString('o')
        $GUID = if ($TemplateId) { $TemplateId } else { (New-Guid).Guid }
        # Name shown for the template; defaults to the app's name
        $TemplateName = "$($Request.Body.TemplateName)".Trim()
        $Template = [ordered]@{
            GUID         = $GUID
            TemplateName = if ($TemplateName) { $TemplateName } elseif ($Existing.TemplateName) { $Existing.TemplateName } else { $AppName }
            AppName      = $AppName
            Description  = "$($Manifest.description.short)"
            Developer    = "$($Manifest.developer.name)"
            ManifestId   = "$ManifestId"
            Version      = "$($Manifest.version)"
            # File name of the uploaded package
            FileName     = "$($Request.Body.FileName)"
            PackageSize  = $Bytes.Length
            Package      = $Package
            CreatedBy    = if ($Existing) { $Existing.CreatedBy } else { $UserName }
            CreatedOn    = if ($Existing) { $Existing.CreatedOn } else { $Now }
            UpdatedBy    = $UserName
            UpdatedOn    = $Now
        }
        $Json = [CIPP.CippJson]::ToJson($Template, 5) ?? (ConvertTo-Json -InputObject $Template -Depth 5 -Compress)
        $Table.Force = $true
        Add-CIPPAzDataTableEntity @Table -Entity @{
            PartitionKey = 'CustomAppTemplate'
            RowKey       = $GUID
            JSON         = [string]$Json
        }
        Write-LogMessage -headers $Headers -API $APIName -message "Saved custom app template '$($Template.TemplateName)' ($AppName $($Template.Version))" -sev Info
        $Body = @{
            Results  = "Saved the template for $AppName $($Template.Version)."
            Metadata = @{ TemplateId = $GUID; TemplateName = $Template.TemplateName }
        }
        $StatusCode = [HttpStatusCode]::OK
    } catch {
        $Body = @{ Results = "Failed to save the custom app template: $($_.Exception.Message)" }
        $StatusCode = Get-CippErrorStatusCode -ErrorRecord $_
    }

    return ([HttpResponseContext]@{ StatusCode = $StatusCode; Body = $Body })
}
