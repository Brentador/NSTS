function Get-JsonContent {
    <#
    .SYNOPSIS
        Reads JSON content from a file and converts it into a PowerShell object.

    .DESCRIPTION
        This function reads the raw content of a JSON file specified by the Path parameter,
        parses it into a PowerShell object, and logs the process using Write-Log.
        It throws an error if the file does not exist or if parsing fails.

    .PARAMETER Path
        The full path to the JSON file to be read and parsed.

    .OUTPUTS
        PSCustomObject or Array
        The parsed JSON content as PowerShell objects.

    .EXAMPLE
        $data = Get-JsonContent -Path "C:\data\sample.json"
        # Reads and parses the JSON file into $data

    .NOTES
        Requires a Write-Log function to handle logging.
        Throws exceptions for file not found or parse errors.
    #>
    
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

