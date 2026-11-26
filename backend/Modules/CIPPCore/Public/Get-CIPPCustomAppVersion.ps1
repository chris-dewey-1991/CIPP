function Get-CIPPCustomAppVersion {
    <#
    .SYNOPSIS
        Highest version among an app catalog entry's app definitions
    .FUNCTIONALITY
        Internal
    #>
    [CmdletBinding()]
    param($App)

    $Highest = $null
    foreach ($Definition in $App.appDefinitions) {
        $Version = "$($Definition.version)"
        if (-not $Version) { continue }
        if ($null -eq $Highest -or (Compare-CIPPCustomAppVersion -Installed $Highest -Template $Version) -lt 0) { $Highest = $Version }
    }
    $Highest
}
