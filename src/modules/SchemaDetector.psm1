function Get-JsonSchema {
    param (
        [Parameter(Mandatory)] $JsonData
    )

    $firstRecord = $JsonData[0]

    $properties = $firstRecord.PSObject.Properties.Name
    $PrimaryKeyField = $properties | Where-Object {
        $_ -match '^(id|.*Id|.*_id|.*ID|.*const|pk)$'
    } | Select-Object -First 1

    if (-not $PrimaryKeyField) {
        $PrimaryKeyField = $properties[0]
        Write-Host "No ID field found, using first property as primary key: $PrimaryKeyField"
    }
    else {
        Write-Host "Using detected primary key field: $PrimaryKeyField"
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

    }
    else {
        $MainTableName = "records"
        Write-Host "Using default table name: $MainTableName" -ForegroundColor Yellow
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
                    IsPrimaryKey = ($propertyName -eq $PrimaryKeyField)
                }
            }
            "SimpleArray" {
                $relatedTableName = $propertyName
                $relatedPK = "${propertyName}_id"
                
                $schema.Tables += @{
                    Name         = $relatedTableName
                    PrimaryKey   = $relatedPK
                    RelationType = "ManyToMany"
                    Columns      = @(
                        @{ Name = $relatedPK; Type = "INTEGER PRIMARY KEY AUTOINCREMENT"; IsPrimaryKey = $true }
                        @{ Name = "${propertyName}_name"; Type = "TEXT"; IsPrimaryKey = $false }
                    )
                }

                $junctionTableName = "${MainTableName}_${propertyName}"
                $schema.JunctionTables += @{
                    TableName = $junctionTableName
                    Table1    = $MainTableName
                    Table1FK  = $PrimaryKeyField
                    Table2    = $relatedTableName
                    Table2FK  = $relatedPK
                    Columns   = @(
                        @{ Name = $PrimaryKeyField; Type = Get-SqlType -Value $firstRecord.$PrimaryKeyField }
                        @{ Name = $relatedPK; Type = "INTEGER" }
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

                $junctionTableName = "${MainTableName}_${propertyName}"
                $schema.JunctionTables += @{
                    TableName = $junctionTableName
                    Table1    = $MainTableName
                    Table1FK  = $PrimaryKeyField
                    Table2    = $relatedTableName
                    Table2FK  = $relatedPK
                    Columns   = @(
                        @{ Name = $PrimaryKeyField; Type = Get-SqlType -Value $firstRecord.$PrimaryKeyField }
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
                }
                else {
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

    if ($null -eq $Value) { return "TEXT" }
    
    $type = $Value.GetType().Name
    switch ($type) {
        "String" { return "TEXT" }
        "Int32" { return "INTEGER" }
        "Int64" { return "INTEGER" }
        "Double" { return "REAL" }
        "Boolean" { return "INTEGER" }
        default { return "TEXT" }
    }
}

Export-ModuleMember -Function Get-JsonSchema