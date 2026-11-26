# Pester tests for Invoke-ExecCustomAppTemplate
# Covers reading the uploaded app package (base64 .zip with a top-level manifest.json), the refusals for files that
# are not usable app packages, the one-template-per-app rule, and the row written for a valid package.

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    Add-Type -Path (Join-Path $RepoRoot 'Shared/CIPPSharp/bin/CIPPSharp.dll')
    Add-Type -AssemblyName System.IO.Compression

    class HttpResponseContext {
        [int]$StatusCode
        [object]$Body
        [object]$ContentType
    }

    function Get-CIPPTable { param($TableName) @{} }
    function Test-CippTemplateWriteAccess { param($Permission, $PartitionKey, $RowKey) $true }
    function Get-CIPPAzDataTableEntity { param($Filter, $Property) $script:StoredRows }
    function Add-CIPPAzDataTableEntity { param([switch]$Force, $Entity) $script:Written = $Entity }
    function Remove-CIPPAzDataTableEntity { param($Entity, [switch]$Force) $script:Removed = $Entity }
    function Write-LogMessage { param($headers, $API, $message, $sev, $tenant, $LogData) }
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/Get-CippErrorStatusCode.ps1')

    $EndpointPath = Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Tenant/Administration/Custom Apps/Invoke-ExecCustomAppTemplate.ps1'
    . ([ScriptBlock]::Create("using namespace System.Net`n" + (Get-Content -LiteralPath $EndpointPath -Raw)))

    $script:AppId = '6f1c2d3e-4a5b-4c6d-8e7f-0123456789ab'

    function script:New-Package {
        param([hashtable]$Files)
        $Stream = [System.IO.MemoryStream]::new()
        $Zip = [System.IO.Compression.ZipArchive]::new($Stream, [System.IO.Compression.ZipArchiveMode]::Create, $true)
        foreach ($Name in $Files.Keys) {
            $Writer = [System.IO.StreamWriter]::new($Zip.CreateEntry($Name).Open())
            $Writer.Write($Files[$Name])
            $Writer.Dispose()
        }
        $Zip.Dispose()
        [Convert]::ToBase64String($Stream.ToArray())
    }

    function script:New-Manifest {
        param($Id = $script:AppId, $Version = '1.2.0')
        ConvertTo-Json -Depth 5 -InputObject @{ id = $Id; version = $Version; name = @{ short = 'NP Portal' }; description = @{ short = 'Client portal' }; developer = @{ name = 'Net Primates' } }
    }

    function script:Invoke-Save {
        param($Package, $TemplateId, $TemplateName)
        $Principal = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('{"UserDetails":"tech@example.com"}'))
        $Request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecCustomAppTemplate' }
            Headers = @{ 'x-ms-client-principal' = $Principal }
            Body    = [pscustomobject]@{ Action = 'Save'; Package = $Package; FileName = 'app.zip'; TemplateId = $TemplateId; TemplateName = $TemplateName }
        }
        Invoke-ExecCustomAppTemplate -Request $Request -TriggerMetadata $null
    }
}

Describe 'Invoke-ExecCustomAppTemplate Save' {
    BeforeEach {
        $script:StoredRows = @()
        $script:Written = $null
    }

    It 'stores the manifest details and the package for a valid app package' {
        $Package = New-Package -Files @{ 'manifest.json' = (New-Manifest); 'color.png' = 'x'; 'outline.png' = 'y' }

        $Response = Invoke-Save -Package "data:application/x-zip-compressed;base64,$Package"

        $Response.StatusCode | Should -Be 200
        $script:Written.PartitionKey | Should -Be 'CustomAppTemplate'
        $Stored = $script:Written.JSON | ConvertFrom-Json
        $Stored.ManifestId | Should -Be $script:AppId
        $Stored.Version | Should -Be '1.2.0'
        $Stored.TemplateName | Should -Be 'NP Portal'
        $Stored.Developer | Should -Be 'Net Primates'
        $Stored.Package | Should -Be $Package
        $Stored.CreatedBy | Should -Be 'tech@example.com'
    }

    It 'refuses a file that is not a zip' {
        $Response = Invoke-Save -Package ([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('not a zip')))
        $Response.StatusCode | Should -Be 400
        $Response.Body.Results | Should -BeLike '*not a .zip app package*'
        $script:Written | Should -BeNullOrEmpty
    }

    It 'refuses a zip whose manifest is inside a folder' {
        $Response = Invoke-Save -Package (New-Package -Files @{ 'NP Portal/manifest.json' = (New-Manifest) })
        $Response.StatusCode | Should -Be 400
        $Response.Body.Results | Should -BeLike '*no manifest.json at its top level*'
    }

    It 'refuses a manifest without a valid app id' {
        $Response = Invoke-Save -Package (New-Package -Files @{ 'manifest.json' = (New-Manifest -Id 'not-a-guid') })
        $Response.StatusCode | Should -Be 400
        $Response.Body.Results | Should -BeLike '*no valid app id*'
    }

    It 'refuses a second template for an app another template already holds' {
        $script:StoredRows = @([pscustomobject]@{ PartitionKey = 'CustomAppTemplate'; RowKey = '11111111-1111-1111-1111-111111111111'; JSON = (@{ TemplateName = 'Existing'; ManifestId = $script:AppId } | ConvertTo-Json) })
        $Response = Invoke-Save -Package (New-Package -Files @{ 'manifest.json' = (New-Manifest) })
        $Response.StatusCode | Should -Be 400
        $Response.Body.Results | Should -BeLike "*'Existing' already holds this app*"
        $script:Written | Should -BeNullOrEmpty
    }

    It 'replaces the package of the template it was asked to update and keeps its name and creator' {
        $TemplateId = '11111111-1111-1111-1111-111111111111'
        $script:StoredRows = @([pscustomobject]@{ PartitionKey = 'CustomAppTemplate'; RowKey = $TemplateId; JSON = (@{ TemplateName = 'Portal'; ManifestId = $script:AppId; CreatedBy = 'first@example.com'; CreatedOn = '2026-01-01' } | ConvertTo-Json) })

        $Response = Invoke-Save -Package (New-Package -Files @{ 'manifest.json' = (New-Manifest -Version '1.3.0') }) -TemplateId $TemplateId

        $Response.StatusCode | Should -Be 200
        $script:Written.RowKey | Should -Be $TemplateId
        $Stored = $script:Written.JSON | ConvertFrom-Json
        $Stored.Version | Should -Be '1.3.0'
        $Stored.TemplateName | Should -Be 'Portal'
        $Stored.CreatedBy | Should -Be 'first@example.com'
        $Stored.UpdatedBy | Should -Be 'tech@example.com'
    }

    It 'returns 404 when the template to update no longer exists' {
        $Response = Invoke-Save -Package (New-Package -Files @{ 'manifest.json' = (New-Manifest) }) -TemplateId '22222222-2222-2222-2222-222222222222'
        $Response.StatusCode | Should -Be 404
    }
}
