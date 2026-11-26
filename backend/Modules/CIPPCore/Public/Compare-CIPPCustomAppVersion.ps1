function Compare-CIPPCustomAppVersion {
    <#
    .SYNOPSIS
        Compares an installed app version with a template version: -1 older, 0 same, 1 newer
    .DESCRIPTION
        App manifests use semantic versions. A pre-release or build suffix is ignored when both sides parse as
        versions; versions that don't parse compare as equal only when the text matches, otherwise as older.
    .FUNCTIONALITY
        Internal
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [string]$Installed,
        [string]$Template
    )

    if (-not $Installed) { return -1 }
    $InstalledVersion = $null
    $TemplateVersion = $null
    if ([version]::TryParse($Installed.Split('-+'.ToCharArray())[0], [ref]$InstalledVersion) -and [version]::TryParse($Template.Split('-+'.ToCharArray())[0], [ref]$TemplateVersion)) {
        return [Math]::Sign($InstalledVersion.CompareTo($TemplateVersion))
    }
    if ($Installed -eq $Template) { 0 } else { -1 }
}
