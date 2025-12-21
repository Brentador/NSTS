. "$PSScriptRoot\Private\JsonReader.ps1"
. "$PSScriptRoot\Private\SchemaDetector.ps1"
. "$PSScriptRoot\Private\SchemaValidator.ps1"
. "$PSScriptRoot\Private\SQLConverter.ps1"
. "$PSScriptRoot\Private\Logger.ps1"

Add-Type -AssemblyName System.Windows.Forms

function Open-File([string]$filter, [string]$title) {
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.filter = $filter
    $OpenFileDialog.Title = $title
    $OpenFileDialog.ShowDialog() | Out-Null
    return $OpenFileDialog.FileName
}

function Save-File([string]$filter, [string]$defaultName, [string]$title) {
    $SaveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $SaveFileDialog.filter = $filter
    $SaveFileDialog.FileName = $defaultName
    $SaveFileDialog.Title = $title
    $SaveFileDialog.ShowDialog() | Out-Null
    return $SaveFileDialog.FileName
}


# JSON to Schema
function JsonToSchema {
    param (
        [hashtable]$RelationshipOverrides = @{}
    )

    Initialize-Logger -LogDirectory ".\logs\json-to-schema" -LogPrefix "json-to-schema"
    $jsonPath = Open-File "JSON Files (*.json)|*.json" "Select JSON File"
    if ([string]::IsNullOrEmpty($jsonPath)) {
        Write-Host "No file was chosen." -ForegroundColor Yellow
        return
    }

    Write-Host "You chose FileName: $jsonPath"
    $jsonData = Get-JsonContent -Path $jsonPath
    Write-Host "`nDetecting schema..." -ForegroundColor Yellow
    $schema = Get-JsonSchema -JsonData $jsonData -RelationshipOverrides $RelationshipOverrides
    $validatedSchema = Confirm-Schema -Schema $schema

    if ($null -ne $validatedSchema) {
        $outputPath = Save-File "JSON Files (*.json)|*.json" "schema.json" "Save Schema File"
        if ([string]::IsNullOrEmpty($outputPath)) {
            Write-Host "No save location chosen. Schema not saved." -ForegroundColor Yellow
            return
        }
        Save-SchemaToFile -Schema $validatedSchema -OutputPath $outputPath
        Write-Host "`nSchema successfully saved!" -ForegroundColor Green
        Write-Host "You can now convert this schema to SQL." -ForegroundColor Cyan
    } else {
        Write-Host "`nSchema validation cancelled." -ForegroundColor Red
    }
}

#test function
function JsonToSchemaFromObject {
    param (
        [Parameter(Mandatory)]
        $JsonData,
        [hashtable]$RelationshipOverrides = @{}
    )
    $schema = Get-JsonSchema -JsonData $JsonData -RelationshipOverrides $RelationshipOverrides
    return $schema
}

# Schema to SQL
function SchemaToSql {
    Initialize-Logger -LogDirectory ".\logs\schema-to-sql" -LogPrefix "schema-to-sql"
    $schemaPath = Open-File "JSON Schema Files (*.json)|*.json|All JSON Files (*.json)|*.json" "Select Schema JSON File"
    if ([string]::IsNullOrEmpty($schemaPath)) {
        Write-Host "No schema file selected. Exiting." -ForegroundColor Yellow
        return
    }

    Write-Host "Loading schema from: $schemaPath" -ForegroundColor Cyan

    try {
        $schemaJson = Get-Content -Path $schemaPath -Raw | ConvertFrom-Json
        $schema = $schemaJson.schema
    } catch {
        Write-Host "Error loading schema file: $_" -ForegroundColor Red
        return
    }

    Write-Host "`nGenerating SQL statements..." -ForegroundColor Yellow
    $sqlStatements = ConvertTo-SqlStatements -Schema $schema

    Write-Host "`n=== GENERATED SQL ===" -ForegroundColor Green
    foreach ($sql in $sqlStatements) {
        Write-Host "`n$sql`n" -ForegroundColor White
    }

    $defaultSqlName = [System.IO.Path]::GetFileNameWithoutExtension($schemaPath) -replace '^schema_?', ''
    $sqlPath = Save-File "SQL Files (*.sql)|*.sql" "$defaultSqlName.sql" "Save SQL File"

    if ([string]::IsNullOrEmpty($sqlPath)) {
        Write-Host "No save location chosen. SQL not saved." -ForegroundColor Yellow
    } else {
        $sqlStatements | Out-File -FilePath $sqlPath -Encoding UTF8
        Write-Host "`nSQL saved to: $sqlPath" -ForegroundColor Green
    }
}

function SchemaToSqlFromObject {
    param (
        [Parameter(Mandatory)]
        $Schema
    )
    
    $sqlStatements = ConvertTo-SqlStatements -Schema $Schema
    return $sqlStatements
}

function Show-Menu {
    Clear-Host
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "        NSTS - JSON/Schema/SQL Tool       " -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  1. Convert JSON to Schema"
    Write-Host "  2. Convert Schema to SQL"
    Write-Host "  Q. Quit"
    Write-Host ""
}

Export-ModuleMember -Function Show-Menu, Open-File, Save-File, JsonToSchema, SchemaToSql, Initialize-Logger, Write-Log, JsonToSchemaFromObject, SchemaToSqlFromObject