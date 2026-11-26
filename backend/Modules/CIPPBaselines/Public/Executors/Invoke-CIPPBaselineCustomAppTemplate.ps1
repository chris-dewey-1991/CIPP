function Invoke-CIPPBaselineCustomAppTemplate {
    <#
    .SYNOPSIS
        CustomAppTemplate executor: publishes the app or updates it to the template's version.
    .DESCRIPTION
        Hands the template and the catalog entry the hook matched to Set-CIPPCustomApp, which publishes a missing
        app and adds the template's version to an older one. Throws when the write fails so the run records an error.
    .FUNCTIONALITY
        Internal
    #>
    [CmdletBinding()]
    param(
        $Remediate,
        $TenantFilter,
        $Current
    )

    if (-not $Current.template) { throw 'CustomAppTemplate: the template could not be read.' }
    $Result = Set-CIPPCustomApp -TenantFilter $TenantFilter -Template $Current.template -Existing $Current.existingApp -ExistingRead -APIName 'Baselines'
    if ($Result.state -eq 'error') { throw $Result.resultText }
}
