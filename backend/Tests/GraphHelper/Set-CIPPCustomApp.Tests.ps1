# Pester tests for Set-CIPPCustomApp and the version helpers it uses.
# Pins the publish-vs-update decision against the tenant's app catalog: a missing app is published, an older
# version gets the template's version added, an equal or newer version is left alone, and a failure comes back as
# an error result rather than a throw so multi-tenant deploys keep going.

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    function New-GraphGetRequest { param($uri, $tenantid) }
    function New-GraphPOSTRequest { param($uri, $tenantid, $type, $body, $contentType) }
    function Write-LogMessage { param($headers, $API, $tenant, $message, $sev, $LogData) }
    function Get-CippException { param($Exception) [pscustomobject]@{ NormalizedError = "$($Exception.Exception.Message)" } }
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/Compare-CIPPCustomAppVersion.ps1')
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/Get-CIPPCustomAppVersion.ps1')
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/Set-CIPPCustomApp.ps1')

    $script:Template = [pscustomobject]@{
        TemplateName = 'Portal'
        AppName      = 'NP Portal'
        ManifestId   = '6f1c2d3e-4a5b-4c6d-8e7f-0123456789ab'
        Version      = '1.2.0'
        Package      = [Convert]::ToBase64String([byte[]](1, 2, 3))
    }
    function script:New-CatalogApp {
        param([string[]]$Versions)
        [pscustomobject]@{ id = 'catalog-id'; externalId = $script:Template.ManifestId; appDefinitions = @($Versions | ForEach-Object { [pscustomobject]@{ version = $_ } }) }
    }
}

Describe 'Compare-CIPPCustomAppVersion' {
    It 'compares <Installed> with <Template> as <Expected>' -ForEach @(
        @{ Installed = '1.0.0'; Template = '1.2.0'; Expected = -1 }
        @{ Installed = '1.10.0'; Template = '1.9.0'; Expected = 1 }
        @{ Installed = '1.2.0'; Template = '1.2.0'; Expected = 0 }
        @{ Installed = '1.2.0-beta'; Template = '1.2.0'; Expected = 0 }
        @{ Installed = ''; Template = '1.0.0'; Expected = -1 }
        @{ Installed = 'v-one'; Template = 'v-two'; Expected = -1 }
    ) {
        Compare-CIPPCustomAppVersion -Installed $Installed -Template $Template | Should -Be $Expected
    }

    It 'picks the highest app definition version, not the last listed' {
        Get-CIPPCustomAppVersion -App (New-CatalogApp -Versions '1.10.0', '1.9.0') | Should -Be '1.10.0'
    }
}

Describe 'Set-CIPPCustomApp' {
    BeforeEach { Mock New-GraphPOSTRequest {} }

    It 'publishes the package when the tenant does not have the app' {
        Mock New-GraphGetRequest { $null }
        $Result = Set-CIPPCustomApp -TenantFilter 'contoso.com' -Template $script:Template
        $Result.state | Should -Be 'success'
        Should -Invoke New-GraphPOSTRequest -Times 1 -Exactly -ParameterFilter { $uri -eq 'https://graph.microsoft.com/v1.0/appCatalogs/teamsApps' -and $contentType -eq 'application/zip' -and $body.Length -eq 3 }
    }

    It 'looks the app up by its manifest id' {
        Mock New-GraphGetRequest { $null }
        $null = Set-CIPPCustomApp -TenantFilter 'contoso.com' -Template $script:Template
        Should -Invoke New-GraphGetRequest -Times 1 -Exactly -ParameterFilter { $uri -like "*externalId eq '$($script:Template.ManifestId)'*" -and $tenantid -eq 'contoso.com' }
    }

    It 'adds the template version to an app on an older version' {
        $Result = Set-CIPPCustomApp -TenantFilter 'contoso.com' -Template $script:Template -Existing (New-CatalogApp -Versions '1.0.0') -ExistingRead
        $Result.resultText | Should -BeLike '*from 1.0.0 to 1.2.0*'
        Should -Invoke New-GraphPOSTRequest -Times 1 -Exactly -ParameterFilter { $uri -eq 'https://graph.microsoft.com/v1.0/appCatalogs/teamsApps/catalog-id/appDefinitions' }
    }

    It 'leaves an app on <Version> alone' -ForEach @(@{ Version = '1.2.0' }, @{ Version = '2.0.0' }) {
        $Result = Set-CIPPCustomApp -TenantFilter 'contoso.com' -Template $script:Template -Existing (New-CatalogApp -Versions $Version) -ExistingRead
        $Result.state | Should -Be 'success'
        Should -Invoke New-GraphPOSTRequest -Times 0
    }

    It 'returns an error result instead of throwing when Graph refuses the upload' {
        Mock New-GraphGetRequest { $null }
        Mock New-GraphPOSTRequest { throw 'Forbidden' }
        $Result = Set-CIPPCustomApp -TenantFilter 'contoso.com' -Template $script:Template
        $Result.state | Should -Be 'error'
        $Result.resultText | Should -BeLike '*Forbidden*contoso.com'
    }

    It 'refuses a template without a valid app id before calling Graph' {
        Mock New-GraphGetRequest {}
        $Broken = $script:Template.PSObject.Copy()
        $Broken.ManifestId = "x' or 1 eq 1"
        $Result = Set-CIPPCustomApp -TenantFilter 'contoso.com' -Template $Broken
        $Result.state | Should -Be 'error'
        Should -Invoke New-GraphGetRequest -Times 0
    }
}
