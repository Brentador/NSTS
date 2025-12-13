Import-Module "$PSScriptRoot\modules\SQLConverter.psm1" -Force

Add-Type -AssemblyName System.Windows.Forms

function Open-SchemaFile {
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.filter = "JSON Schema Files (schema*.json)|schema*.json|All JSON Files (*.json)|*.json"
    $OpenFileDialog.Title = "Select Schema JSON File"
    $OpenFileDialog.ShowDialog() | Out-Null

    return $OpenFileDialog.FileName
}

function Save-SqlFile {
    $SaveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $SaveFileDialog.filter = "SQL Files (*.sql)|*.sql"
    $SaveFileDialog.FileName = "queries"
    $SaveFileDialog.Title = "Save SQL File"
    $SaveFileDialog.ShowDialog() | Out-Null

    return $SaveFileDialog.FileName
}

$schemaPath = Open-SchemaFile

if ([string]::IsNullOrEmpty($schemaPath)) {
    Write-Host "No schema file selected. Exiting." -ForegroundColor Yellow
    exit
}

Write-Host "Loading schema from: $schemaPath" -ForegroundColor Cyan

try {
    $schemaJson = Get-Content -Path $schemaPath -Raw | ConvertFrom-Json
    $schema = $schemaJson.schema
} catch {
    Write-Host "Error loading schema file: $_" -ForegroundColor Red
    exit
}

Write-Host "`nGenerating SQL statements..." -ForegroundColor Yellow
$sqlStatements = ConvertTo-SqlStatements -Schema $schema

Write-Host "`n=== GENERATED SQL ===" -ForegroundColor Green
foreach ($sql in $sqlStatements) {
    Write-Host "`n$sql`n" -ForegroundColor White
}

$defaultSqlName = [System.IO.Path]::GetFileNameWithoutExtension($schemaPath) -replace '^schema_?', ''
$sqlPath = Save-SqlFile -defaultName "$defaultSqlName.sql"

if ([string]::IsNullOrEmpty($sqlPath)) {
    Write-Host "No save location chosen. SQL not saved." -ForegroundColor Yellow
} else {
    $sqlStatements | Out-File -FilePath $sqlPath -Encoding UTF8
    Write-Host "`nSQL saved to: $sqlPath" -ForegroundColor Green
}