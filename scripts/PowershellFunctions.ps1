function Get-InstalledSoftwareVersion {
    param(
        [Parameter(Mandatory=$true)]
        [string]$softwareName,
        [string]$commandName
    )

    $softwareInstalled = $false
    $softwareVersion = ""

    try {
        $softwareVersion = & $commandName --version 2>&1
        $softwareInstalled = $true
    } catch {
        $softwareInstalled = $false
    }

    if ($softwareInstalled) {
        Write-Host "$softwareName is installed. Version: $softwareVersion"
        return $softwareVersion
    } else {
        Write-Host "$softwareName is not installed."
        return $null
    }
}
