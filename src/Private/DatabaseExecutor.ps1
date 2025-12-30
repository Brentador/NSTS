function Invoke-MySqlScript {
    <#
    .SYNOPSIS
        Executes a MySQL script using mysql.exe with provided credentials.

    .DESCRIPTION
        This function runs a MySQL script file against a specified database using mysql.exe.
        It creates a temporary option file for credentials to avoid command-line exposure,
        executes the script via stdin, and returns the output. Logs success or errors.

    .PARAMETER MySqlExePath
        The full path to the mysql.exe executable.

    .PARAMETER Server
        The MySQL server address (e.g., localhost).

    .PARAMETER Database
        The target database name.

    .PARAMETER Username
        The MySQL username.

    .PARAMETER Password
        The MySQL password (plain text, used securely in temp file).

    .PARAMETER SqlFile
        The path to the SQL script file to execute.

    .OUTPUTS
        String
        The standard output from mysql.exe if successful.

    .EXAMPLE
        Invoke-MySqlScript -MySqlExePath "C:\mysql\bin\mysql.exe" -Server "localhost" -Database "test" -Username "root" -Password "pass" -SqlFile "C:\script.sql"
        # Executes the SQL script and returns output.

    .NOTES
        Requires mysql.exe and proper permissions. Cleans up temp files in finally block.
        Throws on file not found or execution errors.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$MySqlExePath,

        [Parameter(Mandatory)]
        [string]$Server,

        [Parameter(Mandatory)]
        [string]$Database,

        [Parameter(Mandatory)]
        [string]$Username,

        [Parameter(Mandatory)]
        [string]$Password,

        [Parameter(Mandatory)]
        [string]$SqlFile
    )

    if (-not (Test-Path $MySqlExePath)) {
        throw "mysql.exe not found at $MySqlExePath"
    }
    if (-not (Test-Path $SqlFile)) {
        throw "SQL file not found at $SqlFile"
    }

    # Create temp MySQL option file
    $optionFile = [System.IO.Path]::GetTempFileName()
    @"
[client]
user=$Username
password=$Password
host=$Server
database=$Database
"@ | Set-Content -Path $optionFile -Encoding ASCII

    try {
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $MySqlExePath
        $processInfo.Arguments = "--defaults-extra-file=`"$optionFile`""
        $processInfo.RedirectStandardInput = $true
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true
        $processInfo.UseShellExecute = $false

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        $process.Start() | Out-Null

        # Send SQL exactly as written
        $process.StandardInput.Write(
            [System.IO.File]::ReadAllText($SqlFile, [Text.Encoding]::UTF8)
        )
        $process.StandardInput.Close()

        $output = $process.StandardOutput.ReadToEnd()
        $errorOutput = $process.StandardError.ReadToEnd()
        $process.WaitForExit()

        if ($process.ExitCode -ne 0) {
            throw $errorOutput
        }

        Write-Log "SQL script executed successfully." -Level "INFO"
        return $output
    }
    finally {
        # Always clean up credentials file
        if (Test-Path $optionFile) {
            Remove-Item $optionFile -Force
        }
    }
}

# Prompts the user to execute a SQL file on a MySQL database after SQL generation.
function Prompt-ExecuteMySql {
    <#
    .SYNOPSIS
        Prompts the user to execute a MySQL script and handles input securely.

    .DESCRIPTION
        This function asks the user if they want to execute a SQL file on MySQL.
        If yes, it collects mysql.exe path, server, database, and credentials using Get-Credential,
        then calls Invoke-MySqlScript to execute the script.

    .PARAMETER SqlFile
        The path to the SQL script file to potentially execute.

    .OUTPUTS
        None
        Executes the script or skips with a message.

    .EXAMPLE
        Prompt-ExecuteMySql -SqlFile "C:\generated.sql"
        # Prompts user and executes if confirmed.

    .NOTES
        Uses Get-Credential for secure password input. Calls Invoke-MySqlScript for execution.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$SqlFile
    )

    $choice = Read-Host "Do you want to execute this SQL on a MySQL database now? (Y/N)"
    if ($choice -notin @('Y', 'y')) {
        Write-Host "Skipping database execution." -ForegroundColor Yellow
        return
    }

    $mysqlExe = Read-Host "Enter path to mysql.exe (e.g., C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe)"
    $server = Read-Host "Enter MySQL server address (default: localhost)"
    if (-not $server) { $server = 'localhost' }
    $database = Read-Host "Enter target database name"
    $credential = Get-Credential -Message "Enter MySQL credentials"
    $username = $credential.UserName
    $password = $credential.GetNetworkCredential().Password


    Invoke-MySqlScript -MySqlExePath $mysqlExe -Server $server -Database $database -Username $username -Password $password -SqlFile $SqlFile
}