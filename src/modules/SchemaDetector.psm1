function Get-JsonSchema {
    param (
        [Parameter(Mandatory)] $JsonData
    )

    Write-Log "Starting schema detection for JSON data." -Level "INFO"

    $firstRecord = $JsonData[0]

    $properties = $firstRecord.PSObject.Properties.Name
    $PrimaryKeyField = $properties | Where-Object {
        $_ -match '^(id|.*Id|.*_id|.*ID|.*const|pk)$'
    } | Select-Object -First 1

    $autoGenerateId = $false
    if (-not $PrimaryKeyField) {
        $PrimaryKeyField = "id"
        $autoGenerateId = $true
        Write-Host "No ID field found. Generating 'id' column as primary key." -ForegroundColor Cyan
        Write-Log "No primary key found in JSON, generating 'id' as primary key." -Level "INFO"
    }
    else {
        Write-Host "Using detected primary key field: $PrimaryKeyField"
        Write-Log "Detected primary key field: $PrimaryKeyField" -Level "INFO"
    }

    if ($PrimaryKeyField -match '^(.+?)(Id|_id|ID|const)$') {
        $baseName = $matches[1]

        if ($baseName.Length -eq 1) {
            $MainTableName = "${baseName}_records"
        }
        else {
            if ($baseName -notmatch 's$') {
                $MainTableName = "${baseName}s"
            }
            else {
                $MainTableName = $baseName
            }
        }
        Write-Host "Detected table name: $MainTableName" -ForegroundColor Green
        Write-Log "Detected table name: $MainTableName" -Level "INFO"

    }
    else {
        $MainTableName = "[REPLACE WITH TABLE NAME]"
        Write-Host "Using default table name: $MainTableName" -ForegroundColor Yellow
        Write-Log "Using default table name placeholder." -Level "WARNING"
    }
    $schema = @{
        Tables         = @()
        JunctionTables = @()
    }

    $baseTable = @{
        Name       = $MainTableName
        PrimaryKey = $PrimaryKeyField
        Columns    = @()
    }
    
    if ($autoGenerateId) {
        $baseTable.Columns += @{
            Name         = "id"
            Type         = "INT"
            IsPrimaryKey = $true
        }
    }

    $properties = $firstRecord.PSObject.Properties

    foreach ($property in $properties) {
        $propertyName = $property.Name
        $value = $property.Value
        
        $fieldType = Get-FieldType -Value $value

        switch ($fieldType) {
            "SimpleValue" {
                $baseTable.Columns += @{
                    Name         = $propertyName
                    Type         = Get-SqlType -Value $value
                    IsPrimaryKey = ($propertyName -eq $PrimaryKeyField) -and (-not $autoGenerateId)
                }
            }
            "SimpleArray" {
                $relatedTableName = $propertyName
                $relatedPK = "${propertyName}_id"
                
                $elementType = if ($value.Count -gt 0) { 
                    Get-SqlType -Value $value[0] 
                } else { 
                    "VARCHAR(255)" 
                }
                
                $schema.Tables += @{
                    Name         = $relatedTableName
                    PrimaryKey   = $relatedPK
                    RelationType = "ManyToMany"
                    Columns      = @(
                        @{ Name = $relatedPK; Type = "INT"; IsPrimaryKey = $true }
                        @{ Name = "${propertyName}_value"; Type = $elementType; IsPrimaryKey = $false }
                    )
                }

                Write-Log "Detected simple array for property '$propertyName', creating related table '$relatedTableName'." -Level "INFO"

                $parentPKType = if ($autoGenerateId) { 
                    "INT" 
                } else { 
                    Get-SqlType -Value $firstRecord.$PrimaryKeyField 
                }

                $junctionTableName = "${MainTableName}_${propertyName}"
                $schema.JunctionTables += @{
                    TableName = $junctionTableName
                    Table1    = $MainTableName
                    Table1FK  = $PrimaryKeyField
                    Table2    = $relatedTableName
                    Table2FK  = $relatedPK
                    Columns   = @(
                        @{ Name = $PrimaryKeyField; Type = $parentPKType }
                        @{ Name = $relatedPK; Type = "INT" }
                    )
                }
            }
            "ObjectArray" {
                $relatedTableName = $propertyName
                $firstElement = $value[0]
                $objectKeys = @($firstElement.PSObject.Properties.Name)
                $relatedPK = $objectKeys[0]
                
                $schema.Tables += @{
                    Name         = $relatedTableName
                    PrimaryKey   = $relatedPK
                    RelationType = "ManyToMany"
                    Columns      = @($objectKeys | ForEach-Object { 
                            @{ 
                                Name         = $_
                                Type         = Get-SqlType -Value $firstElement.$_
                                IsPrimaryKey = ($_ -eq $relatedPK)
                            } 
                        })
                }

                Write-Log "Detected object array for property '$propertyName', creating related table '$relatedTableName'." -Level "INFO"

                $parentPKType = if ($autoGenerateId) { 
                    "INT" 
                } else { 
                    Get-SqlType -Value $firstRecord.$PrimaryKeyField 
                }

                $junctionTableName = "${MainTableName}_${propertyName}"
                $schema.JunctionTables += @{
                    TableName = $junctionTableName
                    Table1    = $MainTableName
                    Table1FK  = $PrimaryKeyField
                    Table2    = $relatedTableName
                    Table2FK  = $relatedPK
                    Columns   = @(
                        @{ Name = $PrimaryKeyField; Type = $parentPKType }
                        @{ Name = $relatedPK; Type = Get-SqlType -Value $firstElement.$relatedPK }
                    )
                }
            }
            "SingleObject" {
                $nestedProperties = $value.PSObject.Properties
                $nestedKeys = @($nestedProperties.Name)
                
                $hasIdField = $nestedKeys | Where-Object { $_ -match '^(id|.*const|.*_id)$' }
                
                if ($hasIdField) {
                    $relatedTableName = $propertyName
                    $relatedPK = $nestedKeys[0]
                    
                    $schema.Tables += @{
                        Name         = $relatedTableName
                        PrimaryKey   = $relatedPK
                        RelationType = "OneToMany"
                        Columns      = @($nestedKeys | ForEach-Object {
                                @{
                                    Name         = $_
                                    Type         = Get-SqlType -Value $value.$_
                                    IsPrimaryKey = ($_ -eq $relatedPK)
                                }
                            })
                    }
                    
                    $fkColumnName = "${propertyName}_id"
                    $baseTable.Columns += @{
                        Name             = $fkColumnName
                        Type             = Get-SqlType -Value $value.$relatedPK
                        IsPrimaryKey     = $false
                        IsForeignKey     = $true
                        ReferencesTable  = $relatedTableName
                        ReferencesColumn = $relatedPK
                    }

                    Write-Log "Detected single object with ID for property '$propertyName', creating related table '$relatedTableName' and foreign key." -Level "INFO"
                }
                else {
                    Write-Log "Detected single object without ID for property '$propertyName', flattening into base table." -Level "INFO"
                    foreach ($nestedProp in $nestedProperties) {
                        $baseTable.Columns += @{
                            Name         = $nestedProp.Name
                            Type         = Get-SqlType -Value $nestedProp.Value
                            IsPrimaryKey = $false
                        }
                    }
                }
            }
        }
    }
    $schema.Tables = @($baseTable) + $schema.Tables
    Write-Log "Schema detection completed with $($schema.Tables.Count) tables and $($schema.JunctionTables.Count) junction tables." -Level "INFO"
    return $schema
}

function Get-FieldType {
    param ($Value)

    if ($null -eq $Value) { return "SimpleValue" }
    
    if ($Value -is [System.Array]) {
        if ($Value.Count -eq 0) { return "SimpleArray" }
        
        if ($Value[0] -is [Hashtable] -or $Value[0] -is [PSCustomObject]) {
            return "ObjectArray"
        }
        else {
            return "SimpleArray"
        }
    }
    
    if ($Value -is [Hashtable] -or $Value -is [PSCustomObject]) {
        return "SingleObject"
    }
    
    return "SimpleValue"
}

function Get-SqlType {
    param ($Value)

    if ($null -eq $Value) { return "VARCHAR(255)" }
    
    $type = $Value.GetType().Name
    switch ($type) {
        "String" {
            if ($Value.Length -gt 255) {
                return "TEXT"
            }
            return "VARCHAR(255)"
        }
        "Int32" { return "INT" }
        "Int64" { return "INT" }
        "Double" { return "FLOAT" }
        "Boolean" { return "BOOLEAN" }
        "DateTime" { return "DATETIME" }
        default { 
            Write-Log "Unknown type '$type' detected, defaulting to VARCHAR(255)." -Level "WARNING"
            return "VARCHAR(255)" 
        }
    }
}

Export-ModuleMember -Function Get-JsonSchema