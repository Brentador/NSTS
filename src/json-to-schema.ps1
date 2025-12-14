Import-Module "$PSScriptRoot\modules\JsonReader.psm1" -Force
Import-Module "$PSScriptRoot\modules\SchemaDetector.psm1" -Force
Import-Module "$PSScriptRoot\modules\SchemaValidator.psm1" -Force
Import-Module "$PSScriptRoot\modules\SQLConverter.psm1" -Force
Import-Module "$PSScriptRoot\modules\Logger.psm1" -Force

Initialize-Logger -LogDirectory ".\logs\json-to-schema" -LogPrefix "json-to-schema"

Add-Type -AssemblyName System.Windows.Forms


function Open-File([string] $initialDirectory){

    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null

    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "JSON Files (*.json)|*.json"
    $OpenFileDialog.ShowDialog() |  Out-Null

    return $OpenFileDialog.filename
} 

$jsonPath = Open-File

if ($OpenFile -ne "") 
{
    echo "You choose FileName: $OpenFile" 
} 
else 
{
    echo "No File was chosen"
}

$jsonData = Get-JsonContent -Path $jsonPath

Write-Host "`nDetecting schema..." -ForegroundColor Yellow
$schema = Get-JsonSchema -JsonData $jsonData
$validatedSchema = Confirm-Schema -Schema $schema

if ($null -ne $validatedSchema) {
    function Save-File([string] $initialDirectory){

    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null

    $OpenFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.FileName = "schema"
    $OpenFileDialog.filter = "JSON Files (*.json)|*.json"
    $OpenFileDialog.ShowDialog() |  Out-Null

    return $OpenFileDialog.filename
    }
    
    $outputPath = Save-File 

    Save-SchemaToFile -Schema $validatedSchema -OutputPath $outputPath
    Write-Host "`nSchema successfully saved!" -ForegroundColor Green
    Write-Host "Run '.\schema-to-sql.ps1' to convert this schema to SQL." -ForegroundColor Cyan


} else {
    Write-Host "`nSchema validation cancelled." -ForegroundColor Red
}