Import-Module "$PSScriptRoot\modules\JsonReader.psm1" -Force
Import-Module "$PSScriptRoot\modules\SchemaDetector.psm1" -Force
Import-Module "$PSScriptRoot\modules\SchemaValidator.psm1" -Force

$jsonPath = "$PSScriptRoot\..\data\sample_imdb.json"
$jsonData = Get-JsonContent -Path $jsonPath

Write-Host "`nDetecting schema..." -ForegroundColor Yellow
$schema = Get-JsonSchema -JsonData $jsonData
$validatedSchema = Confirm-Schema -Schema $schema

if ($null -ne $validatedSchema) {
    $schemaOutputPath = "$PSScriptRoot\..\output\schema_movies.json"
    
    $outputDir = Split-Path $schemaOutputPath -Parent
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir | Out-Null
    }
    
    Save-SchemaToFile -Schema $validatedSchema -OutputPath $schemaOutputPath
    
    Write-Host "`nNext step: Generate SQL statements..." -ForegroundColor Cyan
} else {
    Write-Host "`nSchema validation cancelled." -ForegroundColor Red
}