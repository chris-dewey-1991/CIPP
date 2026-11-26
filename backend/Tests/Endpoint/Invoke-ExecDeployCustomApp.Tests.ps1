# Pester tests for Invoke-ExecDeployCustomApp
# Pins the tenant scoping (a scoped role only reaches its own tenants, AllTenants included) and the per-tenant
# status: all deployed 200, some failed 207, unknown template 404.

BeforeAll {
    $RepoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    Add-Type -Path (Join-Path $RepoRoot 'Shared/CIPPSharp/bin/CIPPSharp.dll')

    class HttpResponseContext {
        [int]$StatusCode
        [object]$Body
        [object]$ContentType
    }

    function Get-CIPPTable { param($TableName) @{} }
    function Get-CIPPAzDataTableEntity { param($Filter, $Property) $script:TemplateRow }
    function Get-Tenants { param([switch]$IncludeErrors) @(
            [pscustomobject]@{ customerId = 'c1'; defaultDomainName = 'one.com' }
            [pscustomobject]@{ customerId = 'c2'; defaultDomainName = 'two.com' }
        ) }
    function Test-CippAccess { param($Request, [switch]$TenantList) $script:Allowed }
    function Set-CIPPCustomApp { param($TenantFilter, $Template, $Headers, $APIName) }
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/Get-CippErrorStatusCode.ps1')
    . (Join-Path $RepoRoot 'Modules/CIPPCore/Public/Get-CippBulkStatusCode.ps1')

    $EndpointPath = Join-Path $RepoRoot 'Modules/CIPPHTTP/Public/Entrypoints/HTTP Functions/Tenant/Administration/Custom Apps/Invoke-ExecDeployCustomApp.ps1'
    . ([ScriptBlock]::Create("using namespace System.Net`n" + (Get-Content -LiteralPath $EndpointPath -Raw)))

    $script:TemplateId = '11111111-1111-1111-1111-111111111111'
    function script:Invoke-Deploy {
        param([string[]]$Tenants)
        $Request = [pscustomobject]@{
            Params  = @{ CIPPEndpoint = 'ExecDeployCustomApp' }
            Headers = @{}
            Body    = [pscustomobject]@{ TemplateId = $script:TemplateId; selectedTenants = @($Tenants | ForEach-Object { [pscustomobject]@{ value = $_ } }) }
        }
        Invoke-ExecDeployCustomApp -Request $Request -TriggerMetadata $null
    }
}

Describe 'Invoke-ExecDeployCustomApp' {
    BeforeEach {
        $script:TemplateRow = [pscustomobject]@{ PartitionKey = 'CustomAppTemplate'; RowKey = $script:TemplateId; JSON = '{"TemplateName":"Portal","ManifestId":"6f1c2d3e-4a5b-4c6d-8e7f-0123456789ab","Version":"1.0.0","Package":"AQID"}' }
        $script:Allowed = @('AllTenants')
        Mock Set-CIPPCustomApp { @{ state = 'success'; resultText = "ok $TenantFilter" } }
    }

    It 'deploys to every tenant when AllTenants is selected' {
        $Response = Invoke-Deploy -Tenants 'AllTenants'
        $Response.StatusCode | Should -Be 200
        Should -Invoke Set-CIPPCustomApp -Times 2 -Exactly
    }

    It 'keeps a scoped role to its own tenants, AllTenants included' {
        $script:Allowed = @('c2')
        $null = Invoke-Deploy -Tenants 'AllTenants'
        Should -Invoke Set-CIPPCustomApp -Times 1 -Exactly -ParameterFilter { $TenantFilter -eq 'two.com' }
        Should -Invoke Set-CIPPCustomApp -Times 0 -ParameterFilter { $TenantFilter -eq 'one.com' }
    }

    It 'refuses a scoped role with 403 when none of the selected tenants are allowed' {
        $script:Allowed = @('c2')
        $Response = Invoke-Deploy -Tenants 'one.com'
        $Response.StatusCode | Should -Be 403
        Should -Invoke Set-CIPPCustomApp -Times 0
    }

    It 'returns 207 when some tenants fail' {
        Mock Set-CIPPCustomApp { @{ state = 'error'; resultText = 'failed' } } -ParameterFilter { $TenantFilter -eq 'one.com' }
        $Response = Invoke-Deploy -Tenants 'one.com', 'two.com'
        $Response.StatusCode | Should -Be 207
        @($Response.Body.Results).Count | Should -Be 2
    }

    It 'returns 404 for a template that no longer exists' {
        $script:TemplateRow = $null
        $Response = Invoke-Deploy -Tenants 'one.com'
        $Response.StatusCode | Should -Be 404
    }
}
