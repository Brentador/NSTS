function Get-JsonSchema {
    param (
        [Parameter(Mandatory)] $JsonData,
        [hashtable]$RelationshipOverrides = @{}
    )

    Write-Log "Starting schema detection for JSON data." -Level "INFO"

    $firstRecord = $JsonData[0]
    $properties = $firstRecord.PSObject.Properties.Name

    $pkResult = Get-PrimaryKeyField $properties
    $PrimaryKeyField = $pkResult.Field
    $autoGenerateId = $pkResult.AutoGenerate

    if ($autoGenerateId) {
        Write-Host "No ID field found. Generating 'id' column as primary key." -ForegroundColor Cyan
        Write-Log "No primary key found in JSON, generating 'id' as primary key." -Level "INFO"
    }
    else {
        Write-Host "Using detected primary key field: $PrimaryKeyField"
        Write-Log "Detected primary key field: $PrimaryKeyField" -Level "INFO"
    }

    $MainTableName = Get-MainTableName $PrimaryKeyField
    if ($MainTableName -eq "[REPLACE WITH TABLE NAME]") {
        Write-Host "Using default table name: $MainTableName" -ForegroundColor Yellow
        Write-Log "Using default table name placeholder." -Level "WARNING"
    }
    else {
        Write-Host "Detected table name: $MainTableName" -ForegroundColor Green
        Write-Log "Detected table name: $MainTableName" -Level "INFO"
    }

    $schema = @{
        Tables             = @()
        JunctionTables     = @()
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
                $baseTable.Columns += Get-SimpleValue $propertyName $value $PrimaryKeyField $autoGenerateId
            }
            "SimpleArray" {
                $schema = Add-SimpleArray $propertyName $value $MainTableName $PrimaryKeyField $autoGenerateId $firstRecord $schema
                Write-Log "Detected simple array for property '$propertyName', creating related table '$propertyName'." -Level "INFO"
            }
            "ObjectArray" {
                $schema = Add-ObjectArray $propertyName $value $MainTableName $PrimaryKeyField $autoGenerateId $firstRecord $schema $JsonData $RelationshipOverrides
                Write-Log "Detected object array for property '$propertyName', creating related table '$propertyName'." -Level "INFO"
            }
            "SingleObject" {
                $result = Add-SingleObject $propertyName $value $baseTable $schema
                $baseTable = $result[0]
                $schema = $result[1]
            }
        }
    }
    $schema.Tables = @($baseTable) + $schema.Tables
    
    Write-Log "Schema detection completed with $($schema.Tables.Count) tables and $($schema.JunctionTables.Count) junction tables." -Level "INFO"
    return $schema
}

function Get-PrimaryKeyField {
    param ($properties)
    $PrimaryKeyField = $properties | Where-Object {
        $_ -match '^(id|.*Id|.*_id|.*ID|.*const|pk)$'
    } | Select-Object -First 1
    if (-not $PrimaryKeyField) {
        return @{ Field = "id"; AutoGenerate = $true }
    }
    return @{ Field = $PrimaryKeyField; AutoGenerate = $false }
}

function Get-MainTableName {
    param ($PrimaryKeyField)
    if ($PrimaryKeyField -match '^(.+?)(Id|_id|ID|const)$') {
        $baseName = $matches[1]
        if ($baseName.Length -eq 1) {
            return "${baseName}_records"
        }
        elseif ($baseName -notmatch 's$') {
            return "${baseName}s"
        }
        else {
            return $baseName
        }
    }
    return "[REPLACE WITH TABLE NAME]"
}

function Get-SimpleValue {
    param ($propertyName, $value, $PrimaryKeyField, $autoGenerateId)
    return @{
        Name         = $propertyName
        Type         = Get-SqlType -Value $value
        IsPrimaryKey = ($propertyName -eq $PrimaryKeyField) -and (-not $autoGenerateId)
    }
}

function Add-SimpleArray {
    param ($propertyName, $value, $MainTableName, $PrimaryKeyField, $autoGenerateId, $firstRecord, $schema)
    $relatedTableName = $propertyName
    $relatedPK = "${propertyName}_id"
    $elementType = if ($value.Count -gt 0) { Get-SqlType -Value $value[0] } else { "VARCHAR(255)" }
    $schema.Tables += @{
        Name         = $relatedTableName
        PrimaryKey   = $relatedPK
        RelationType = "ManyToMany"
        Columns      = @(
            @{ Name = $relatedPK; Type = "INT"; IsPrimaryKey = $true }
            @{ Name = "${propertyName}_value"; Type = $elementType; IsPrimaryKey = $false }
        )
    }
    $parentPKType = if ($autoGenerateId) { "INT" } else { Get-SqlType -Value $firstRecord.$PrimaryKeyField }
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
    return $schema
}

function Add-ObjectArray {
    param (
        $propertyName, 
        $value, 
        $MainTableName, 
        $PrimaryKeyField, 
        $autoGenerateId, 
        $firstRecord, 
        $schema,
        $AllRecords,
        $Overrides
    )
    
    if ($Overrides -and $Overrides.ContainsKey($propertyName)) {
        $relationType = $Overrides[$propertyName]
        Write-Host "  → $propertyName (object array → $relationType - MANUAL OVERRIDE)" -ForegroundColor Cyan
        
        if ($relationType -eq "OneToMany") {
            return Add-OneToManyObjectArray $propertyName $value $MainTableName $PrimaryKeyField $autoGenerateId $firstRecord $schema
        }
        else {
            return Add-ManyToManyObjectArray $propertyName $value $MainTableName $PrimaryKeyField $autoGenerateId $firstRecord $schema
        }
    }
    
    $firstElement = $value[0]
    $properties = @($firstElement.PSObject.Properties.Name)
    
    $hasRealId = $properties | Where-Object { $_ -match '^(id|.*_id|.*ID|pk)$' } | Select-Object -First 1
    
    if ($hasRealId) {
        $detectionResult = Get-RelationTypeById $propertyName $AllRecords $hasRealId
        $relationType = $detectionResult.Type
        $reason = $detectionResult.Reason
    }
    else {
        $detectionResult = Get-RelationTypeByComposite $propertyName $value $AllRecords $properties
        
        if ($detectionResult.Type -eq "ManyToMany") {
            $relationType = "ManyToMany"
            $reason = "$($detectionResult.Reason) (no ID field - may be false positive)"
        }
        else {
            $relationType = "OneToMany"
            $reason = "No ID field found - assuming child objects belong to single parent"
        }
    }
    
    Write-Host "    $propertyName (object array → $relationType)" -ForegroundColor Yellow
    Write-Host "    Reason: $reason" -ForegroundColor Gray
    
    if ($relationType -eq "OneToMany") {
        return Add-OneToManyObjectArray $propertyName $value $MainTableName $PrimaryKeyField $autoGenerateId $firstRecord $schema
    }
    else {
        return Add-ManyToManyObjectArray $propertyName $value $MainTableName $PrimaryKeyField $autoGenerateId $firstRecord $schema
    }
}

function Get-RelationTypeById {
    param ($PropertyName, $AllRecords, $PkField)
    
    $childToParentsMap = @{}
    $parentIndex = 0
    foreach ($record in $AllRecords) {
        if ($record.$PropertyName) {
            foreach ($obj in $record.$PropertyName) {
                $childId = $obj.$PkField
                if ($null -eq $childId) {
                    Write-Log "Null ID found in '$PropertyName', skipping" -Level "WARNING"
                    continue
                }
                if (-not $childToParentsMap.ContainsKey($childId)) {
                    $childToParentsMap[$childId] = @()
                }
                if ($childToParentsMap[$childId] -notcontains $parentIndex) {
                    $childToParentsMap[$childId] += $parentIndex
                }
            }
        }
        $parentIndex++
    }
    $sharedIds = @()
    foreach ($childId in $childToParentsMap.Keys) {
        if ($childToParentsMap[$childId].Count -gt 1) {
            $sharedIds += $childId
        }
    }
    if ($sharedIds.Count -gt 0) {
        return @{
            Type   = "ManyToMany"
            Reason = "Found $($sharedIds.Count) shared ID(s) across multiple parents"
        }
    }
    return @{
        Type   = "OneToMany"
        Reason = "Has ID field, but no IDs are shared in sample"
    }
}

function Get-RelationTypeByComposite {
    param ($PropertyName, $Value, $AllRecords, $Properties)
    
    # Filter out metadata fields
    $meaningfulFields = $Properties | Where-Object { 
        $_ -notmatch '(timestamp|created|updated|modified|version|date)' 
    }
    
    if ($meaningfulFields.Count -eq 0) {
        return @{ 
            Type   = "OneToMany"
            Reason = "No meaningful fields to compare"
        }
    }
    
    $compositeToParentsMap = @{}
    $parentIndex = 0
    foreach ($record in $AllRecords) {
        if ($record.$PropertyName) {
            foreach ($obj in $record.$PropertyName) {
                $compositeValues = $meaningfulFields | ForEach-Object { $obj.$_ }
                $compositeKey = ($compositeValues | ForEach-Object { if ($null -eq $_) { "null" } else { $_.ToString() } }) -join "|"
                if (-not $compositeToParentsMap.ContainsKey($compositeKey)) {
                    $compositeToParentsMap[$compositeKey] = @()
                }
                if ($compositeToParentsMap[$compositeKey] -notcontains $parentIndex) {
                    $compositeToParentsMap[$compositeKey] += $parentIndex
                }
            }
        }
        $parentIndex++
    }
    $sharedObjects = @()
    foreach ($compositeKey in $compositeToParentsMap.Keys) {
        if ($compositeToParentsMap[$compositeKey].Count -gt 1) {
            $sharedObjects += $compositeKey
        }
    }
    if ($sharedObjects.Count -gt 0) {
        return @{
            Type   = "ManyToMany"
            Reason = "Found $($sharedObjects.Count) identical composite object(s) across parents (may be false positive)"
        }
    }
    return @{
        Type   = "OneToMany"
        Reason = "No identical objects found in sample"
    }
}


function Add-OneToManyObjectArray {
    param ($propertyName, $value, $MainTableName, $PrimaryKeyField, $autoGenerateId, $firstRecord, $schema)
    
    $relatedTableName = $propertyName
    $firstElement = $value[0]
    $objectKeys = @($firstElement.PSObject.Properties.Name)
    
    # Check if there's an existing ID field
    $relatedPK = $objectKeys | Where-Object { $_ -match '^(id|.*_id|.*ID)$' } | Select-Object -First 1
    if (-not $relatedPK) {
        $relatedPK = "${propertyName}_id"
    }
    
    $parentPKType = if ($autoGenerateId) { "INT" } else { Get-SqlType -Value $firstRecord.$PrimaryKeyField }
    
    $columns = @(
        @{ Name = $relatedPK; Type = "INT"; IsPrimaryKey = $true }
    )
    
    # Add all other columns
    foreach ($key in $objectKeys) {
        if ($key -ne $relatedPK) {
            $columns += @{
                Name         = $key
                Type         = Get-SqlType -Value $firstElement.$key
                IsPrimaryKey = $false
            }
        }
    }
    
    # Add foreign key to parent
    $columns += @{
        Name             = "${MainTableName}_${PrimaryKeyField}"
        Type             = $parentPKType
        IsPrimaryKey     = $false
        IsForeignKey     = $true
        ReferencesTable  = $MainTableName
        ReferencesColumn = $PrimaryKeyField
    }
    
    $schema.Tables += @{
        Name         = $relatedTableName
        PrimaryKey   = $relatedPK
        RelationType = "OneToMany"
        Columns      = $columns
    }
    
    Write-Log "Created OneToMany table '$relatedTableName' with FK to '$MainTableName'" -Level "INFO"
    return $schema
}

function Add-ManyToManyObjectArray {
    param ($propertyName, $value, $MainTableName, $PrimaryKeyField, $autoGenerateId, $firstRecord, $schema)
    
    $relatedTableName = $propertyName
    $firstElement = $value[0]
    $objectKeys = @($firstElement.PSObject.Properties.Name)
    
    # Use first field as PK (or detected ID field)
    $relatedPK = $objectKeys | Where-Object { $_ -match '^(id|.*_id|.*ID)$' } | Select-Object -First 1
    if (-not $relatedPK) {
        $relatedPK = $objectKeys[0]
    }
    
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
    
    $parentPKType = if ($autoGenerateId) { "INT" } else { Get-SqlType -Value $firstRecord.$PrimaryKeyField }
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
    
    Write-Log "Created ManyToMany table '$relatedTableName' with junction table '$junctionTableName'" -Level "INFO"
    return $schema
}

function Add-SingleObject {
    param ($propertyName, $value, $baseTable, $schema)

    $nestedProperties = $value.PSObject.Properties
    $nestedKeys = @($nestedProperties.Name)

    $hasIdField = $nestedKeys | Where-Object { $_ -match '^(id|.*const|.*_id)$' }

    if ($hasIdField) {
        $relatedPK = $hasIdField | Select-Object -First 1
    }
    else {
        $relatedPK = "${propertyName}_pk"
    }

    $relatedTableName = $propertyName

    $schema.Tables += @{
        Name         = $relatedTableName
        PrimaryKey   = $relatedPK
        RelationType = "OneToMany"
        Columns      = @(
            @{
                Name         = $relatedPK
                Type         = "INT"
                IsPrimaryKey = $true
            }
        ) + ($nestedKeys | ForEach-Object {
                @{
                    Name         = $_
                    Type         = Get-SqlType -Value $value.$_
                    IsPrimaryKey = $false
                }
            })
    }

    $schema.Tables[-1].Columns += @{
        Name             = "${baseTable.Name}_id"
        Type             = "INT"
        IsPrimaryKey     = $false
        IsForeignKey     = $true
        ReferencesTable  = $baseTable.Name
        ReferencesColumn = $baseTable.PrimaryKey
    }

    return @($baseTable, $schema)
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

