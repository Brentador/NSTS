function Get-JsonContent {
    param (
        [string]$Path
    )

    if (-Not (Test-Path $Path)) {
        throw "File not found: $Path"
    }

    $jsonContent = Get-Content -Path $Path -Raw | ConvertFrom-Json
    return $jsonContent
}

Export-ModuleMember -Function Get-JsonContent