function Invoke-MySqlScript {
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
        Write-Error "mysql.exe not found at $MySqlExePath"
        return
    }
    if (-not (Test-Path $SqlFile)) {
        Write-Error "SQL file not found at $SqlFile"
        return
    }

    $arguments = @(
        "-h", $Server,
        "-u", $Username,
        "-p$Password",
        $Database
    )

    Write-Log "Executing SQL script $SqlFile on MySQL database '$Database' at '$Server'..." -Level "INFO"
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = $MySqlExePath
    $processInfo.Arguments = $arguments -join ' '
    $processInfo.RedirectStandardInput = $true
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true
    $processInfo.UseShellExecute = $false

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processInfo
    $process.Start() | Out-Null

    # Pipe the SQL file into mysql.exe
    Get-Content $SqlFile | ForEach-Object { $process.StandardInput.WriteLine($_) }
    $process.StandardInput.Close()

    $output = $process.StandardOutput.ReadToEnd()
    $errorOutput = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    if ($process.ExitCode -eq 0) {
        Write-Log "SQL script executed successfully." -Level "INFO"
        Write-Output $output
    } else {
        Write-Log "Error executing SQL script: $errorOutput" -Level "ERROR"
        Write-Error $errorOutput
    }
}

# Prompts the user to execute a SQL file on a MySQL database after SQL generation.
function Prompt-And-ExecuteMySql {
    param(
        [Parameter(Mandatory)]
        [string]$SqlFile
    )

    $choice = Read-Host "Do you want to execute this SQL on a MySQL database now? (Y/N)"
    if ($choice -notin @('Y', 'y')) {
        Write-Host "Skipping database execution." -ForegroundColor Yellow
        return
    }

    $mysqlExe = Read-Host "Enter path to mysql.exe (e.g., C:\\Program Files\\MySQL\\MySQL Server 8.0\\bin\\mysql.exe)"
    $server = Read-Host "Enter MySQL server address (default: localhost)"
    if (-not $server) { $server = 'localhost' }
    $database = Read-Host "Enter target database name"
    $username = Read-Host "Enter MySQL username"
    $pwd_secure_string = Read-Host "Enter a Password" -AsSecureString


    Invoke-MySqlScript -MySqlExePath $mysqlExe -Server $server -Database $database -Username $username -Password $pwd_secure_string -SqlFile $SqlFile
}
