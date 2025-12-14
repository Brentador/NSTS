function Get-JsonContent {
    param (
        [string]$Path
    )

    Write-Log "Attempting to read JSON from: $Path" -Level "INFO"

    if (-Not (Test-Path $Path)) {
        Write-Log "File not found: $Path" -Level "ERROR"
        throw "File not found: $Path"
    }

    try {
        $jsonContent = Get-Content -Path $Path -Raw | ConvertFrom-Json
        Write-Log "Successfully read JSON from: $Path" -Level "INFO"
        return $jsonContent
    } catch {
        Write-Log "Failed to parse JSON from $Path. Error: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

Export-ModuleMember -Function Get-JsonContent