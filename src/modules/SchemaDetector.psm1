function Get-JsonSchema {
    param (
        [Parameter(Mandatory)] $JsonData,
        [Parameter(Mandatory)] $MainTableName,
        [Parameter(Mandatory)] $PrimaryKeyField
    )

    $firstRecord = $JsonData[0]

    $schema = @{
        MainTable = @{
            Name = $MainTableName
            PrimaryKey = $PrimaryKeyField
            Columns = @()
        }
        RelatedTables = @()
        JunctionTables = @()
    }

    $properties = $firstRecord.PSObject.Properties

    foreach ($property in $properties) {
        $propertyName = $property.Name
        $value = $property.Value
        
        $fieldType = Get-FieldType -Value $value

        switch ($fieldType) {
            "SimpleValue" {
                $schema.MainTable.Columns += @{
                    Name = $propertyName
                    Type = Get-SqlType -Value $value
                    IsPrimaryKey = ($propertyName -eq $PrimaryKeyField)
                }
            }
            "SimpleArray" {
                $relatedTableName = $propertyName
                $relatedPK = "${propertyName}_id"
                
                $schema.RelatedTables += @{
                    TableName = $relatedTableName
                    PrimaryKey = $relatedPK
                    Columns = @(
                        @{ Name = $relatedPK; Type = "INTEGER PRIMARY KEY AUTOINCREMENT" }
                        @{ Name = "${propertyName}_name"; Type = "TEXT" }
                    )
                }

                $junctionTableName = "${MainTableName}_${propertyName}"
                $schema.JunctionTables += @{
                    TableName = $junctionTableName
                    MainTableFK = $PrimaryKeyField
                    RelatedTableFK = $relatedPK
                    Columns = @(
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
                
                $schema.RelatedTables += @{
                    TableName = $relatedTableName
                    PrimaryKey = $relatedPK
                    Columns = @($objectKeys | ForEach-Object { 
                        @{ 
                            Name = $_
                            Type = Get-SqlType -Value $firstElement.$_
                            IsPrimaryKey = ($_ -eq $relatedPK)
                        } 
                    })
                }

                $junctionTableName = "${MainTableName}_${propertyName}"
                $schema.JunctionTables += @{
                    TableName = $junctionTableName
                    MainTableFK = $PrimaryKeyField
                    RelatedTableFK = $relatedPK
                    Columns = @(
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
                    
                    $schema.RelatedTables += @{
                        TableName = $relatedTableName
                        PrimaryKey = $relatedPK
                        RelationType = "OneToMany"
                        Columns = @($nestedKeys | ForEach-Object {
                            @{
                                Name = $_
                                Type = Get-SqlType -Value $value.$_
                                IsPrimaryKey = ($_ -eq $relatedPK)
                            }
                        })
                    }
                    
                    $fkColumnName = "${propertyName}_id"
                    $schema.MainTable.Columns += @{
                        Name = $fkColumnName
                        Type = Get-SqlType -Value $value.$relatedPK
                        IsPrimaryKey = $false
                        IsForeignKey = $true
                        ReferencesTable = $relatedTableName
                        ReferencesColumn = $relatedPK
                    }
                } else {
                    foreach ($nestedProp in $nestedProperties) {
                        $schema.MainTable.Columns += @{
                            Name = $nestedProp.Name
                            Type = Get-SqlType -Value $nestedProp.Value
                            IsPrimaryKey = $false
                        }
                    }
                }
            }
        }
    }
    return $schema
}

function Get-FieldType {
    param ($Value)

    if ($null -eq $Value) { return "SimpleValue" }
    
    if ($Value -is [System.Array]) {
        if ($Value.Count -eq 0) { return "SimpleArray" }
        
        if ($Value[0] -is [Hashtable] -or $Value[0] -is [PSCustomObject]) {
            return "ObjectArray"
        } else {
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
        "String"  { return "TEXT" }
        "Int32"   { return "INTEGER" }
        "Int64"   { return "INTEGER" }
        "Double"  { return "REAL" }
        "Boolean" { return "INTEGER" }
        default   { return "TEXT" }
    }
}

Export-ModuleMember -Function Get-JsonSchema