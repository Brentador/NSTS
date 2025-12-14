$script:LogPath = ""

function Initialize-Logger {
    param(
        [string]$LogDirectory = ".\logs",
        [string]$LogPrefix = "app"
    )

    if (!(Test-Path $LogDirectory)) {
        New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
    }

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $script:LogPath = Join-Path -Path $LogDirectory -ChildPath "${LogPrefix}_$timestamp.log"
    
    Write-Log "--- Application Started ---" -Level "INFO"
    Write-Log "Log file: $script:LogPath" -Level "INFO"
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("DEBUG", "INFO", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $logEntry = "[$timestamp] [$Level] $Message"

    if ($script:LogPath) {
        Add-Content -Path $script:LogPath -Value $logEntry
    }

    $color = switch ($Level) {
        "DEBUG"   { "Gray" }
        "INFO"    { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
    }
}

Export-ModuleMember -Function Initialize-Logger, Write-Log