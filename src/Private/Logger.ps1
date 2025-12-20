$script:LogPath = ""

function Initialize-Logger {
    <#
    .SYNOPSIS
        Initializes logging for the application.

    .DESCRIPTION
        Sets up a log file in the specified directory with a timestamped name.
        If the directory does not exist, it will be created.
        The log path is stored in the $script:LogPath variable and used by Write-Log.

    .PARAMETER LogDirectory
        The directory where log files will be created. Defaults to ".\logs".

    .PARAMETER LogPrefix
        The prefix used for the log file name. Defaults to "app".

    .OUTPUTS
        None. Initializes $script:LogPath and creates log file entries.

    .EXAMPLE
        Initialize-Logger -LogDirectory ".\logs" -LogPrefix "json-to-schema"
        # Creates a log file in ".\logs" with a name like "json-to-schema_20251220_181500.log"

    .NOTES
        Requires the Write-Log function to be defined.
        Logs the application start and log file path as initial entries.
    #>
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
        <#
    .SYNOPSIS
        Writes a message to the log file with timestamp and severity level.

    .DESCRIPTION
        Formats the message with a timestamp and severity level (DEBUG, INFO, WARNING, ERROR)
        and appends it to the log file specified by $script:LogPath. Does nothing if
        logging has not been initialized.

    .PARAMETER Message
        The message text to write to the log file.

    .PARAMETER Level
        The severity level of the log entry. Must be one of DEBUG, INFO, WARNING, or ERROR.
        Defaults to INFO.

    .OUTPUTS
        None. Appends messages to the log file.

    .EXAMPLE
        Write-Log -Message "Processing started" -Level "INFO"
        # Appends "[2025-12-20T18:15:00.1234567+00:00] [INFO] Processing started" to the current log file.

    .NOTES
        Requires $script:LogPath to be set by Initialize-Logger.
    #>
    param(
        [string]$Message,
        [ValidateSet("DEBUG", "INFO", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )

    $timestamp = (Get-Date).ToString("o")
    $logEntry = "[$timestamp] [$Level] $Message"

    if ($script:LogPath) {
        Add-Content -Path $script:LogPath -Value $logEntry
    }
}