function Show-Schema {
    param (
        [Parameter(Mandatory)]
        [hashtable]$Schema
    )
    
    Write-Host "`n==================== DETECTED SCHEMA ====================" -ForegroundColor Cyan
    
    Write-Host "`n[TABLES]" -ForegroundColor Yellow
    $tableIndex = 0
    foreach ($table in $Schema.Tables) {
        Write-Host "  [" -NoNewline -ForegroundColor White
        Write-Host "$tableIndex" -NoNewline -ForegroundColor Yellow
        Write-Host "] Table: " -NoNewline -ForegroundColor White
        Write-Host "$($table.Name)" -NoNewline -ForegroundColor Cyan
        Write-Host " (PK: " -NoNewline -ForegroundColor Gray
        Write-Host "$($table.PrimaryKey)" -NoNewline -ForegroundColor Yellow
        Write-Host ")" -ForegroundColor Gray
    
        Write-Host "      Columns:" -ForegroundColor DarkGray
    
        foreach ($col in $table.Columns) {
        
            Write-Host "        - " -NoNewline -ForegroundColor DarkGray
            Write-Host "$($col.Name)" -NoNewline -ForegroundColor White
            Write-Host " (" -NoNewline -ForegroundColor DarkGray
            Write-Host "$($col.Type)" -NoNewline -ForegroundColor Magenta
            Write-Host ")" -NoNewline -ForegroundColor DarkGray
        
            if ($col.IsPrimaryKey) {
                Write-Host " <- PRIMARY KEY" -NoNewline -ForegroundColor Yellow
            }
        
            if ($col.IsForeignKey) {
                Write-Host " <- FOREIGN KEY " -NoNewline -ForegroundColor Yellow
                Write-Host "$($col.ReferencesTable)" -NoNewline -ForegroundColor Cyan
            }
        
            Write-Host ""
        }
    
        if ($table.RelationType) {
            Write-Host "      Relation: " -NoNewline -ForegroundColor DarkGray
            Write-Host "$($table.RelationType)" -ForegroundColor Green
        }
        Write-Host "" 
    
        $tableIndex++
    }
    
    Write-Host "`n[RELATIONSHIPS (Junction Tables)]" -ForegroundColor Magenta
    foreach ($junction in $Schema.JunctionTables) {
        Write-Host "  $($junction.TableName)" -ForegroundColor White
        Write-Host "    Links: $($junction.Table1FK) -> $($junction.Table2FK)" -ForegroundColor Gray
    }
    
    Write-Host "`n========================================================`n" -ForegroundColor Cyan
}


# Helper: Add column
function Add-TableColumn {
    param (
        [hashtable]$Table
    )
    $newColName = Read-Host "Enter new column name"
    if ($newColName) {
        $validTypes = @(
            "TINYINT", "SMALLINT", "MEDIUMINT", "INT", "INTEGER", "BIGINT", 
            "DECIMAL", "DEC", "NUMERIC", "FIXED", "FLOAT", "DOUBLE", 
            "DOUBLE PRECISION", "REAL", "BIT", "BOOL", "BOOLEAN", 
            "DATE", "TIME", "DATETIME", "TIMESTAMP", "YEAR", 
            "CHAR", "VARCHAR", "TINYTEXT", "TEXT", "MEDIUMTEXT", "LONGTEXT", 
            "BINARY", "VARBINARY", "TINYBLOB", "BLOB", "MEDIUMBLOB", "LONGBLOB", 
            "ENUM", "SET", "GEOMETRY", "POINT", "LINESTRING", "POLYGON", 
            "MULTIPOINT", "MULTILINESTRING", "MULTIPOLYGON", "GEOMETRYCOLLECTION", 
            "JSON"
        )
        Write-Host "Select a valid dataType from the list: " -ForegroundColor Cyan
        Write-Host "TINYINT, SMALLINT, MEDIUMINT, INT, INTEGER, BIGINT, DECIMAL, DEC, NUMERIC, FIXED, FLOAT, DOUBLE, DOUBLE PRECISION, REAL, BIT, BOOL, BOOLEAN, DATE, TIME, DATETIME, TIMESTAMP, YEAR" -ForegroundColor Magenta
        Write-Host "CHAR, VARCHAR, TINYTEXT, TEXT, MEDIUMTEXT, LONGTEXT, BINARY, VARBINARY, TINYBLOB, BLOB, MEDIUMBLOB, LONGBLOB, ENUM, SET" -ForegroundColor Green
        Write-Host "GEOMETRY, POINT, LINESTRING, POLYGON, MULTIPOINT, MULTILINESTRING, MULTIPOLYGON, GEOMETRYCOLLECTION, JSON" -ForegroundColor DarkBlue
        $newColType = Read-Host "Enter data type for $newColName [VARCHAR(255)]"
        if (-not $newColType) { $newColType = "VARCHAR(255)" }
        $baseType = if ($newColType -match '^(\w+)(\(.*\))?$') { 
            $matches[1].ToUpper() 
        }
        else { 
            $newColType.ToUpper() 
        }
        if ($validTypes -contains $baseType) {
            $Table.Columns += @{ Name = $newColName; Type = $newColType.ToUpper(); IsPrimaryKey = $false }
            Write-Host "Column added!" -ForegroundColor Green
            Write-Log "Added column '$newColName' of type '$newColType' to table '$($Table.Name)'." -Level "INFO"
        }
        else {
            Write-Host "Invalid data type. Column not added." -ForegroundColor Red
            Write-Log "Failed to add column '$newColName': invalid type '$newColType'." -Level "WARNING"
        }
    }
    return $Table
}

# Helper: Remove column
function Remove-TableColumn {
    param (
        [hashtable]$Table
    )
    Write-Host "$($Table.Columns.Count)"
    $columnNum = Read-Host "Enter column number to remove"
    $columnNum = [int]$columnNum
    if ($columnNum -ge 3 -and $columnNum -le $Table.Columns.Count + 1) {
        $actualIndex = $columnNum - 2
        if ($Table.Columns[$actualIndex].IsPrimaryKey) {
            Write-Host "Cannot delete the primary key column." -ForegroundColor Red
        }
        else {
            $Table.Columns = @(
                for ($i = 0; $i -lt $Table.Columns.Count; $i++) {
                    if ($i -ne $actualIndex) {
                        $Table.Columns[$i]
                    }
                }
            )
            Write-Host "Column deleted!" -ForegroundColor Green
            Write-Log "Deleted column from table '$($Table.Name)'." -Level "INFO"
        }
    }
    else {
        Write-Host "Enter a valid column number." -ForegroundColor Red
    }
    return $Table
}

# Helper: Rename table and update references
function Rename-TableAndReferences {
    param (
        [hashtable]$Table,
        [array]$JunctionTables,
        [array]$AllTables,
        [string]$oldTableName,
        [string]$newTableName
    )
    $Table.Name = $newTableName
    foreach ($junction in $JunctionTables) {
        if ($junction.TableName -like "*$oldTableName*") {
            $junction.TableName = $junction.TableName -replace [regex]::Escape($oldTableName), $newTableName
        }
        if ($junction.Table1 -eq $oldTableName) {
            $junction.Table1 = $newTableName
        }
        if ($junction.Table2 -eq $oldTableName) {
            $junction.Table2 = $newTableName
        }
    }
    foreach ($otherTable in $AllTables) {
        if ($otherTable.Name -ne $oldTableName) {
            foreach ($col in $otherTable.Columns) {
                if ($col.IsForeignKey -and $col.ReferencesTable -eq $oldTableName) {
                    $col.ReferencesTable = $newTableName
                }
            }
        }
    }
    Write-Host "Table name updated to $newTableName" -ForegroundColor Green
    Write-Log "Updated table name from '$oldTableName' to '$newTableName'." -Level "INFO"
    return $Table
}

# Helper: Set primary key
function Set-PrimaryKey {
    param (
        [hashtable]$Table,
        [array]$JunctionTables,
        [array]$AllTables
    )
    Write-Host "`nSelect new primary field" -ForegroundColor Cyan
    for ($i = 0; $i -lt $Table.Columns.Count; $i++) {
        $col = $Table.Columns[$i]
        $current = if ($col.IsPrimaryKey) { " <- CURRENT" } else { "" }
        Write-Host "  [$i] $($col.Name)$current" -ForegroundColor White
    }
    $pkChoice = Read-Host "`nColumn number"
    if ($pkChoice -match '^\d+$' -and [int]$pkChoice -lt $Table.Columns.Count) {
        foreach ($col in $Table.Columns) {
            $col.IsPrimaryKey = $false
        }
        $newPKCol = $Table.Columns[[int]$pkChoice]
        $newPKCol.IsPrimaryKey = $true
        $oldPKName = $Table.PrimaryKey
        $Table.PrimaryKey = $newPKCol.Name
        foreach ($junction in $JunctionTables) {
            if ($junction.Table1 -eq $Table.Name -and $junction.Table1FK -eq $oldPKName) {
                $junction.Table1FK = $newPKCol.Name
                $junctionCol = $junction.Columns | Where-Object { $_.Name -eq $oldPKName }
                if ($junctionCol) { $junctionCol.Name = $newPKCol.Name }
            }
            if ($junction.Table2 -eq $Table.Name -and $junction.Table2FK -eq $oldPKName) {
                $junction.Table2FK = $newPKCol.Name
                $junctionCol = $junction.Columns | Where-Object { $_.Name -eq $oldPKName }
                if ($junctionCol) { $junctionCol.Name = $newPKCol.Name }
            }
        }
        foreach ($otherTable in $AllTables) {
            if ($otherTable.Name -ne $Table.Name) {
                foreach ($fkCol in $otherTable.Columns) {
                    if ($fkCol.IsForeignKey -and $fkCol.ReferencesTable -eq $Table.Name -and $fkCol.ReferencesColumn -eq $oldPKName) {
                        $fkCol.ReferencesColumn = $newPKCol.Name
                    }
                }
            }
        }
        Write-Host "Primary key changed to: $($newPKCol.Name)" -ForegroundColor Green
        Write-Log "Changed primary key to '$($newPKCol.Name)' in table '$($Table.Name)'." -Level "INFO"
    }
    return $Table
}

# Helper: Rename column and update references
function Rename-TableColumn {
    param (
        [hashtable]$Table,
        [array]$JunctionTables,
        [array]$AllTables,
        [int]$colIndex
    )
    $col = $Table.Columns[$colIndex]
    $newColName = Read-Host "`nNew column name (current: $($col.Name))"
    if ($newColName) {
        $oldColName = $col.Name
        if ($col.IsPrimaryKey) {
            $Table.PrimaryKey = $newColName
            foreach ($junction in $JunctionTables) {
                if ($junction.Table1 -eq $Table.Name -and $junction.Table1FK -eq $oldColName) {
                    $junction.Table1FK = $newColName
                    $junctionCol = $junction.Columns | Where-Object { $_.Name -eq $oldColName }
                    if ($junctionCol) { $junctionCol.Name = $newColName }
                }
                if ($junction.Table2 -eq $Table.Name -and $junction.Table2FK -eq $oldColName) {
                    $junction.Table2FK = $newColName
                    $junctionCol = $junction.Columns | Where-Object { $_.Name -eq $oldColName }
                    if ($junctionCol) { $junctionCol.Name = $newColName }
                }
            }
            foreach ($otherTable in $AllTables) {
                if ($otherTable.Name -ne $Table.Name) {
                    foreach ($fkCol in $otherTable.Columns) {
                        if ($fkCol.IsForeignKey -and $fkCol.ReferencesTable -eq $Table.Name -and $fkCol.ReferencesColumn -eq $oldColName) {
                            $fkCol.ReferencesColumn = $newColName
                        }
                    }
                }
            }
        }
        $col.Name = $newColName
        Write-Host "Column name updated!" -ForegroundColor Green
        Write-Log "Updated column name to '$newColName' in table '$($Table.Name)'." -Level "INFO"
    }
    return $Table
}

# Helper: Set column type and update references
function Set-TableColumnType {
    param (
        [hashtable]$Table,
        [array]$JunctionTables,
        [int]$colIndex
    )
    $col = $Table.Columns[$colIndex]
    $newColType = Read-Host "New data type [$($col.Type)]"
    if ($newColType) {
        $col.Type = $newColType
        if ($col.IsPrimaryKey) {
            foreach ($junction in $JunctionTables) {
                if ($junction.Table1 -eq $Table.Name -and $junction.Table1FK -eq $col.Name) {
                    $junctionCol = $junction.Columns | Where-Object { $_.Name -eq $col.Name }
                    if ($junctionCol) { 
                        $junctionCol.Type = $newColType
                        Write-Host "  → Updated type in junction table: $($junction.TableName)" -ForegroundColor DarkGray
                    }
                }
                if ($junction.Table2 -eq $Table.Name -and $junction.Table2FK -eq $col.Name) {
                    $junctionCol = $junction.Columns | Where-Object { $_.Name -eq $col.Name }
                    if ($junctionCol) { 
                        $junctionCol.Type = $newColType
                        Write-Host "  → Updated type in junction table: $($junction.TableName)" -ForegroundColor DarkGray
                    }
                }
            }
        }
        Write-Host "Column type updated!" -ForegroundColor Green
        Write-Log "Updated column type to '$newColType' for '$($col.Name)' in table '$($Table.Name)'." -Level "INFO"
    }
    return $Table
}

function Edit-Table {
    param (
        [Parameter(Mandatory)]
        [hashtable]$Table,
        [array]$JunctionTables,
        [Parameter(Mandatory)]
        [array]$AllTables
    )

    if (-not $JunctionTables) {
        $JunctionTables = @()
    }

    Write-Log "Started editing table: $($Table.Name)" -Level "INFO"
    Write-Host "`n--- Editing $($Table.Name) ---" -ForegroundColor Cyan

    $oldTableName = $Table.Name

    $editingTable = $true

    while ($editingTable) {
        Write-Host "`n--- Editing Table: $($Table.Name) ---" -ForegroundColor Cyan
        Write-Host "What do you want to edit?" -ForegroundColor Yellow
        Write-Host "  [0] Table name: $($Table.Name)" -ForegroundColor White
        Write-Host "  [1] Primary key: $($Table.PrimaryKey)" -ForegroundColor White

        for ($i = 0; $i -lt $Table.Columns.Count; $i++) {
            $col = $Table.Columns[$i]
            $pk = if ($col.IsPrimaryKey) { " <- PRIMARY KEY" } else { "" }
            $fk = if ($col.IsForeignKey) { " <- FOREIGN KEY" } else { "" }
            Write-Host "  [$($i + 2)] Column: $($col.Name) ($($col.Type))$pk$fk" -ForegroundColor White
        }

        Write-Host "  [A] Add column" -ForegroundColor Yellow
        Write-Host "  [R] Remove column" -ForegroundColor Yellow
        Write-Host "  [D] Done editing this table" -ForegroundColor Green

        $choice = Read-Host "`nYour choice"

        if ($choice -eq "D" -or $choice -eq "d") {
            $editingTable = $false
            continue
        }
        if ($choice -eq "A" -or $choice -eq "a") {
            $Table = Add-TableColumn -Table $Table
            continue
        }
        if ($choice -eq "R" -or $choice -eq "r") {
            $Table = Remove-TableColumn -Table $Table
            continue
        }
        if ($choice -notmatch '^[ARDard]$' -and $choice -notmatch '^\d+$') {
            Write-Host "Invalid choice. Please enter a valid number, 'A' to add, 'R' to remove or 'D' to finish." -ForegroundColor Red
            continue
        }
        $choiceNum = [int]$choice
        if ($choiceNum -eq 0) {
            $newTableName = Read-Host "New table name [$($Table.Name)]"
            if ($newTableName) {
                $Table = Rename-TableAndReferences -Table $Table -JunctionTables $JunctionTables -AllTables $AllTables -oldTableName $oldTableName -newTableName $newTableName
                $oldTableName = $newTableName
            }
        }
        elseif ($choiceNum -eq 1) {
            $Table = Set-PrimaryKey -Table $Table -JunctionTables $JunctionTables -AllTables $AllTables
        }
        elseif ($choiceNum -ge 2 -and $choiceNum -lt ($Table.Columns.Count + 2)) {
            $colIndex = $choiceNum - 2
            $Table = Rename-TableColumn -Table $Table -JunctionTables $JunctionTables -AllTables $AllTables -colIndex $colIndex
            $Table = Set-TableColumnType -Table $Table -JunctionTables $JunctionTables -colIndex $colIndex
        }
        else {
            Write-Host "Invalid option number." -ForegroundColor Red
        }
    }
    return $Table
}

function Edit-Schema {
    param (
        [Parameter(Mandatory)]
        [hashtable]$Schema
    )
    
    $editing = $true
    
    while ($editing) {
        Show-Schema -Schema $Schema
        
        $tableCount = $Schema.Tables.Count
        Write-Host "Enter table number to edit (0-$($tableCount - 1)), or D to finish:" -ForegroundColor Yellow
        $choice = Read-Host "Your choice"
        
        if ($choice -match '^\d+$' -and [int]$choice -lt $tableCount) {
            $junctionTables = if ($Schema.JunctionTables) { $Schema.JunctionTables } else { @() }
            $Schema.Tables[[int]$choice] = Edit-Table `
                -Table $Schema.Tables[[int]$choice] `
                -JunctionTables $junctionTables `
                -AllTables $Schema.Tables
        }
        elseif ($choice.ToUpper() -eq "D") {
            $editing = $false
        }
        else {
            Write-Host "Invalid choice. Try again." -ForegroundColor Red
        }
    }
    
    return $Schema
}

function Confirm-Schema {

    param (
        [Parameter(Mandatory)]
        [hashtable]$Schema
    )
    
    Show-Schema -Schema $Schema
    
    Write-Host "Do you want to:" -ForegroundColor Yellow
    Write-Host "  [A] Accept this schema as-is" -ForegroundColor Green
    Write-Host "  [E] Edit the schema" -ForegroundColor Cyan
    Write-Host "  [Q] Quit without saving" -ForegroundColor Red
    
    $choice = Read-Host "`nYour choice"
    
    switch ($choice.ToUpper()) {
        "A" { 
            Write-Host "`nSchema accepted!" -ForegroundColor Green
            Write-Log "Schema accepted and confirmed." -Level "INFO"
            return $Schema 
        }
        "E" { 
            $editedSchema = Edit-Schema -Schema $Schema
            return Confirm-Schema -Schema $editedSchema4
        }
        "Q" { 
            Write-Host "`nExiting without saving..." -ForegroundColor Red
            Write-Log "Schema editing exited without saving." -Level "WARNING"
            return $null 
        }
        default { 
            Write-Host "`nInvalid choice. Please try again." -ForegroundColor Red
            return Confirm-Schema -Schema $Schema
        }
    }
}

function Save-SchemaToFile {
    param (
        [Parameter(Mandatory)]
        [hashtable]$Schema,
        
        [Parameter(Mandatory)]
        [string]$OutputPath
    )
    
    Write-Log "Preparing to save schema with $($Schema.Tables.Count) tables and $($Schema.JunctionTables.Count) junction tables" -Level "INFO"

    
    $schemaWithMetadata = @{
        schema        = $Schema
        validated     = $true
        validatedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        version       = "1.0"
    }
    
    $json = $schemaWithMetadata | ConvertTo-Json -Depth 10
    $json | Out-File -FilePath $OutputPath -Encoding UTF8
    
    Write-Host "`nSchema saved to: $OutputPath" -ForegroundColor Green
    Write-Log "Schema saved to file: $OutputPath" -Level "INFO"
}

