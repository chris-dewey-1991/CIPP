# Get-CIPPBaselineCustomAppTemplateState grades one custom app template against the CustomApps cache, and
# Invoke-CIPPBaselineCustomAppTemplate hands the carried template and catalog entry to Set-CIPPCustomApp.

BeforeAll {
    $script:RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    Add-Type -Path (Join-Path $script:RepoRoot 'Shared/CIPPSharp/bin/CIPPSharp.dll')

    function Get-CIPPTable { param($tablename) @{} }
    function Get-CIPPAzDataTableEntity { param($Filter, $Property) $script:TemplateRow }
    function Get-CIPPBaselineCacheRows { param($TenantFilter, $Type) $script:CacheRows }
    function Test-CIPPBaselineCacheCollected { param($TenantFilter, $Type) $script:Collected }
    function Set-CIPPCustomApp { param($TenantFilter, $Template, $Existing, [switch]$ExistingRead, $Headers, $APIName) }
    . (Join-Path $script:RepoRoot 'Modules/CIPPCore/Public/Compare-CIPPCustomAppVersion.ps1')
    . (Join-Path $script:RepoRoot 'Modules/CIPPCore/Public/Get-CIPPCustomAppVersion.ps1')
    . (Join-Path $script:RepoRoot 'Modules/CIPPBaselines/Public/PrepareHooks/Get-CIPPBaselineCustomAppTemplateState.ps1')
    . (Join-Path $script:RepoRoot 'Modules/CIPPBaselines/Public/Executors/Invoke-CIPPBaselineCustomAppTemplate.ps1')

    $script:TemplateId = '11111111-1111-1111-1111-111111111111'
    $script:AppId = '6f1c2d3e-4a5b-4c6d-8e7f-0123456789ab'
    $script:Item = [pscustomobject]@{ Variables = [pscustomobject]@{ customAppTemplate = [pscustomobject]@{ label = 'Portal'; value = $script:TemplateId } } }

    function script:New-CatalogApp {
        param([string]$ExternalId = $script:AppId, [string]$Version)
        [pscustomobject]@{ id = "catalog-$Version"; externalId = $ExternalId; appDefinitions = @([pscustomobject]@{ version = $Version }) }
    }
}

Describe 'Get-CIPPBaselineCustomAppTemplateState' {
    BeforeEach {
        $script:TemplateRow = [pscustomobject]@{ PartitionKey = 'CustomAppTemplate'; RowKey = $script:TemplateId; JSON = (@{ TemplateName = 'Portal'; ManifestId = $script:AppId; Version = '1.2.0'; Package = 'AQID' } | ConvertTo-Json) }
        $script:CacheRows = @()
        $script:Collected = $true
    }

    It 'grades <Status> when the tenant has <Description>' -ForEach @(
        @{ Description = 'no matching app'; Apps = { @(New-CatalogApp -ExternalId '00000000-0000-0000-0000-000000000000' -Version '9.0.0') }; Status = 'Not deployed' }
        @{ Description = 'an older version'; Apps = { @(New-CatalogApp -Version '1.0.0') }; Status = 'Outdated (1.0.0)' }
        @{ Description = 'the template version'; Apps = { @(New-CatalogApp -Version '1.2.0') }; Status = 'Current' }
        @{ Description = 'a newer version'; Apps = { @(New-CatalogApp -Version '1.3.0') }; Status = 'Current' }
    ) {
        $script:CacheRows = & $Apps
        $State = Get-CIPPBaselineCustomAppTemplateState -Item $script:Item -TenantFilter 'contoso.com'
        $State.Expected.appStatus | Should -Be 'Current'
        $State.Current.appStatus | Should -Be $Status
    }

    It 'carries the template and the matched catalog entry for the executor' {
        $script:CacheRows = @(New-CatalogApp -Version '1.0.0')
        $State = Get-CIPPBaselineCustomAppTemplateState -Item $script:Item -TenantFilter 'contoso.com'
        $State.Current.template.ManifestId | Should -Be $script:AppId
        $State.Current.existingApp.id | Should -Be 'catalog-1.0.0'
    }

    It 'is No Data when the cache was never collected' {
        $script:Collected = $false
        $State = Get-CIPPBaselineCustomAppTemplateState -Item $script:Item -TenantFilter 'contoso.com'
        $State.Current | Should -BeNullOrEmpty
        $State.ConfigError | Should -BeNullOrEmpty
    }

    It 'grades Not deployed for a collected but empty catalog' {
        $State = Get-CIPPBaselineCustomAppTemplateState -Item $script:Item -TenantFilter 'contoso.com'
        $State.Current.appStatus | Should -Be 'Not deployed'
    }

    It 'is a configuration error when the template no longer exists' {
        $script:TemplateRow = $null
        $State = Get-CIPPBaselineCustomAppTemplateState -Item $script:Item -TenantFilter 'contoso.com'
        $State.Current | Should -BeNullOrEmpty
        $State.ConfigError | Should -BeTrue
    }
}

Describe 'Invoke-CIPPBaselineCustomAppTemplate' {
    It 'deploys with the catalog entry the hook already read' {
        Mock Set-CIPPCustomApp { @{ state = 'success'; resultText = 'ok' } }
        $Current = [pscustomobject]@{ appStatus = 'Outdated (1.0.0)'; template = [pscustomobject]@{ ManifestId = $script:AppId }; existingApp = (New-CatalogApp -Version '1.0.0') }
        Invoke-CIPPBaselineCustomAppTemplate -Remediate @{} -TenantFilter 'contoso.com' -Current $Current
        Should -Invoke Set-CIPPCustomApp -Times 1 -Exactly -ParameterFilter { $ExistingRead -and $Existing.id -eq 'catalog-1.0.0' -and $TenantFilter -eq 'contoso.com' }
    }

    It 'throws when the deploy fails so the run records an error' {
        Mock Set-CIPPCustomApp { @{ state = 'error'; resultText = 'Failed to deploy' } }
        $Current = [pscustomobject]@{ appStatus = 'Not deployed'; template = [pscustomobject]@{ ManifestId = $script:AppId }; existingApp = $null }
        { Invoke-CIPPBaselineCustomAppTemplate -Remediate @{} -TenantFilter 'contoso.com' -Current $Current } | Should -Throw 'Failed to deploy'
    }
}
