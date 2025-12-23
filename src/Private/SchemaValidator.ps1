# Valid MySQL data types
$script:ValidMySQLTypes = @(
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

function Write-ColorText {
    <#
    .SYNOPSIS
        Writes colored text to the console.

    .DESCRIPTION
        Takes an array of hashtables with Text and Color, and outputs them without newlines except at the end.

    .PARAMETER Parts
        Array of hashtables with Text and Color keys.

    .OUTPUTS
        None
        Outputs to console.

    .EXAMPLE
        Write-ColorText @(
            @{Text = "Hello"; Color = "Red"},
            @{Text = " World"; Color = "Blue"}
        )
    #>
    param(
        [Parameter(ValueFromPipeline)]
        [object[]]$Parts
    )
    
    foreach ($part in $Parts) {
        Write-Host $part.Text -NoNewline -ForegroundColor $part.Color
    }
    Write-Host ""
}

function Show-Schema {
    <#
    .SYNOPSIS
        Displays the detected schema in a formatted way.

    .DESCRIPTION
        Prints tables, columns, relations, and junction tables with colors.

    .PARAMETER Schema
        The schema hashtable to display.

    .OUTPUTS
        None
        Outputs to console.

    .EXAMPLE
        Show-Schema -Schema $schema
    #>
    param (
        [Parameter(Mandatory)]
        [hashtable]$Schema
    )
    
    Write-ColorText @(
        @{Text = "`n==================== DETECTED SCHEMA ===================="; Color = "Cyan" }
    )
    
    Write-ColorText @(
        @{Text = "`n[TABLES]"; Color = "Yellow" }
    )
    $tableIndex = 0
    foreach ($table in $Schema.Tables) {
        Write-ColorText @(
            @{Text = "  ["; Color = "White" }
            @{Text = "$tableIndex"; Color = "Yellow" }
            @{Text = "] Table: "; Color = "White" }
            @{Text = "$($table.Name)"; Color = "Cyan" }
            @{Text = " (PK: "; Color = "Gray" }
            @{Text = "$($table.PrimaryKey)"; Color = "Yellow" }
            @{Text = ")"; Color = "Gray" }
        )
    
        Write-ColorText @(
            @{Text = "      Columns:"; Color = "DarkGray" }
        )
    
        foreach ($col in $table.Columns) {
            $parts = @(
                @{Text = "        - "; Color = "DarkGray" },
                @{Text = "$($col.Name)"; Color = "White" },
                @{Text = " ("; Color = "DarkGray" },
                @{Text = "$($col.Type)"; Color = "Magenta" },
                @{Text = ")"; Color = "DarkGray" }
            )
        
            if ($col.IsPrimaryKey) {
                $parts += @{Text = " <- PRIMARY KEY"; Color = "Yellow" }
            }
        
            if ($col.IsForeignKey) {
                $parts += @{Text = " <- FOREIGN KEY "; Color = "Yellow" }
                $parts += @{Text = "$($col.ReferencesTable)"; Color = "Cyan" }
            }
        
            Write-ColorText $parts
        }
    
        if ($table.RelationType) {
            Write-ColorText @(
                @{Text = "      Relation: "; Color = "DarkGray" },
                @{Text = "$($table.RelationType)"; Color = "Green" }
            )
        }
        Write-Host "" 
    
        $tableIndex++
    }
    
    Write-ColorText @(
        @{Text = "`n[RELATIONSHIPS (Junction Tables)]"; Color = "Magenta" }
    )
    foreach ($junction in $Schema.JunctionTables) {
        Write-ColorText @(
            @{Text = "  $($junction.TableName)"; Color = "White" }
        )
        Write-ColorText @(
            @{Text = "    Links: $($junction.Table1FK) -> $($junction.Table2FK)"; Color = "Gray" }
        )
    }
    
    Write-ColorText @(
        @{Text = "`n========================================================`n"; Color = "Cyan" }
    )
}


# Helper: Add column
function Add-TableColumn {
    <#
    .SYNOPSIS
        Prompts to add a new column to a table.

    .DESCRIPTION
        Asks for column name and type, validates against MySQL types, and adds to the table.

    .PARAMETER Table
        The table hashtable to modify.

    .OUTPUTS
        Modified table hashtable.

    .EXAMPLE
        $table = Add-TableColumn -Table $table
    #>
    param (
        [hashtable]$Table
    )
    $newColName = (Read-Host "Enter new column name").Trim()
    if ($newColName) {
        Write-ColorText @(
            @{Text = "Select a valid dataType from the list: "; Color = "Cyan" }
        )
        Write-ColorText @(
            @{Text = "TINYINT, SMALLINT, MEDIUMINT, INT, INTEGER, BIGINT, DECIMAL, DEC, NUMERIC, FIXED, FLOAT, DOUBLE, DOUBLE PRECISION, REAL, BIT, BOOL, BOOLEAN, DATE, TIME, DATETIME, TIMESTAMP, YEAR"; Color = "Magenta" }
        )
        Write-ColorText @(
            @{Text = "CHAR, VARCHAR, TINYTEXT, TEXT, MEDIUMTEXT, LONGTEXT, BINARY, VARBINARY, TINYBLOB, BLOB, MEDIUMBLOB, LONGBLOB, ENUM, SET"; Color = "Green" }
        )
        Write-ColorText @(
            @{Text = "GEOMETRY, POINT, LINESTRING, POLYGON, MULTIPOINT, MULTILINESTRING, MULTIPOLYGON, GEOMETRYCOLLECTION, JSON"; Color = "DarkBlue" }
        )
        $newColType = (Read-Host "Enter data type for $newColName [VARCHAR(255)]").Trim()
        if (-not $newColType) { $newColType = "VARCHAR(255)" }
        $baseType = if ($newColType -match '^(\w+)(\(.*\))?$') { 
            $matches[1].ToUpper() 
        }
        else { 
            $newColType.ToUpper() 
        }
        if ($script:ValidMySQLTypes -contains $baseType) {
            $Table.Columns += @{ Name = $newColName; Type = $newColType.ToUpper(); IsPrimaryKey = $false }
            Write-ColorText @(
                @{Text = "Column added!"; Color = "Green" }
            )
            Write-Log "Added column '$newColName' of type '$newColType' to table '$($Table.Name)'." -Level "INFO"
        }
        else {
            Write-ColorText @(
                @{Text = "Invalid data type. Column not added."; Color = "Red" }
            )
            Write-Log "Failed to add column '$newColName': invalid type '$newColType'." -Level "WARNING"
        }
    }
    return $Table
}

# Helper: Remove column
function Remove-TableColumn {
    <#
    .SYNOPSIS
        Prompts to remove a column from a table.

    .DESCRIPTION
        Lists columns, asks for index, validates, and removes if not PK.

    .PARAMETER Table
        The table hashtable to modify.

    .OUTPUTS
        Modified table hashtable.

    .EXAMPLE
        $table = Remove-TableColumn -Table $table
    #>
    param (
        [hashtable]$Table
    )

    $columnNumInput = (Read-Host "Enter column number to remove").Trim()
    if ($columnNumInput -match '^\d+$') {
        $columnNum = [int]$columnNumInput
    } else {
        Write-Host "Invalid input. Please enter a number." -ForegroundColor Red
        return $Table
    }

    if ($columnNum -ge 2 -and $columnNum -le ($Table.Columns.Count + 1)) {
        $actualIndex = $columnNum - 2
        if ($Table.Columns[$actualIndex].IsPrimaryKey) {
            Write-ColorText @(
                @{Text = "Cannot delete the primary key column."; Color = "Red" }
            )
        } else {
            $Table.Columns = @(
                for ($i = 0; $i -lt $Table.Columns.Count; $i++) {
                    if ($i -ne $actualIndex) {
                        $Table.Columns[$i]
                    }
                }
            )
            Write-ColorText @(
                @{Text = "Column deleted!"; Color = "Green" }
            )
            Write-Log "Deleted column from table '$($Table.Name)'." -Level "INFO"
        }
    }
    else {
        Write-ColorText @(
            @{Text = "Enter a valid column number."; Color = "Red" }
        )
    }
    return $Table
}

# Helper: Rename table and update references
function Rename-TableAndReferences {
    <#
    .SYNOPSIS
        Renames a table and updates all references.

    .DESCRIPTION
        Changes table name and updates FKs in junction tables and other tables.

    .PARAMETER Table
        The table to rename.

    .PARAMETER JunctionTables
        Array of junction tables.

    .PARAMETER AllTables
        Array of all tables.

    .PARAMETER oldTableName
        Current table name.

    .PARAMETER newTableName
        New table name.

    .OUTPUTS
        Modified table.

    .EXAMPLE
        $table = Rename-TableAndReferences -Table $table -oldTableName "old" -newTableName "new"
    #>
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
    Write-ColorText @(
        @{Text = "Table name updated to $newTableName"; Color = "Green" }
    )
    Write-Log "Updated table name from '$oldTableName' to '$newTableName'." -Level "INFO"
    return $Table
}

# Helper: Set primary key
function Set-PrimaryKey {
    <#
    .SYNOPSIS
        Prompts to change the primary key of a table.

    .DESCRIPTION
        Lists columns, asks for new PK, updates references in junction tables.

    .PARAMETER Table
        The table hashtable.

    .PARAMETER JunctionTables
        Array of junction tables.

    .PARAMETER AllTables
        Array of all tables.

    .OUTPUTS
        Modified table.

    .EXAMPLE
        $table = Set-PrimaryKey -Table $table -JunctionTables $juncs -AllTables $tables
    #>
    param (
        [hashtable]$Table,
        [array]$JunctionTables,
        [array]$AllTables
    )
    Write-ColorText @(
        @{Text = "`nSelect new primary field"; Color = "Cyan" }
    )
    for ($i = 0; $i -lt $Table.Columns.Count; $i++) {
        $col = $Table.Columns[$i]
        $current = if ($col.IsPrimaryKey) { " <- CURRENT" } else { "" }
        Write-ColorText @(
            @{Text = "  [$i] $($col.Name)$current"; Color = "White" }
        )
    }
    $pkChoice = (Read-Host "`nColumn number").Trim()
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
        Write-ColorText @(
            @{Text = "Primary key changed to: $($newPKCol.Name)"; Color = "Green" }
        )
        Write-Log "Changed primary key to '$($newPKCol.Name)' in table '$($Table.Name)'." -Level "INFO"
    }
    return $Table
}

# Helper: Rename column and update references
function Rename-TableColumn {
    <#
    .SYNOPSIS
        Renames a column and updates references.

    .DESCRIPTION
        Asks for new name, updates PK if needed, and fixes FKs.

    .PARAMETER Table
        The table.

    .PARAMETER JunctionTables
        Junction tables.

    .PARAMETER AllTables
        All tables.

    .PARAMETER colIndex
        Index of column to rename.

    .OUTPUTS
        Modified table.

    .EXAMPLE
        $table = Rename-TableColumn -Table $table -colIndex 0
    #>
    param (
        [hashtable]$Table,
        [array]$JunctionTables,
        [array]$AllTables,
        [int]$colIndex
    )
    $col = $Table.Columns[$colIndex]
    $newColName = (Read-Host "`nNew column name (current: $($col.Name))").Trim()
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
        Write-ColorText @(
            @{Text = "Column name updated!"; Color = "Green" }
        )
        Write-Log "Updated column name to '$newColName' in table '$($Table.Name)'." -Level "INFO"
    }
    return $Table
}

# Helper: Set column type and update references
function Set-TableColumnType {
    <#
    .SYNOPSIS
        Changes the data type of a column.

    .DESCRIPTION
        Asks for new type and updates in junction tables if PK.

    .PARAMETER Table
        The table.

    .PARAMETER JunctionTables
        Junction tables.

    .PARAMETER colIndex
        Column index.

    .OUTPUTS
        Modified table.

    .EXAMPLE
        $table = Set-TableColumnType -Table $table -colIndex 0
    #>
    param (
        [hashtable]$Table,
        [array]$JunctionTables,
        [int]$colIndex
    )
    $col = $Table.Columns[$colIndex]
    $newColType = (Read-Host "New data type [$($col.Type)]").Trim()
    if ($newColType) {
        $col.Type = $newColType
        if ($col.IsPrimaryKey) {
            foreach ($junction in $JunctionTables) {
                if ($junction.Table1 -eq $Table.Name -and $junction.Table1FK -eq $col.Name) {
                    $junctionCol = $junction.Columns | Where-Object { $_.Name -eq $col.Name }
                    if ($junctionCol) { 
                        $junctionCol.Type = $newColType
                        Write-ColorText @(
                            @{Text = "  → Updated type in junction table: $($junction.TableName)"; Color = "DarkGray" }
                        )
                    }
                }
                if ($junction.Table2 -eq $Table.Name -and $junction.Table2FK -eq $col.Name) {
                    $junctionCol = $junction.Columns | Where-Object { $_.Name -eq $col.Name }
                    if ($junctionCol) { 
                        $junctionCol.Type = $newColType
                        Write-ColorText @(
                            @{Text = "  → Updated type in junction table: $($junction.TableName)"; Color = "DarkGray" }
                        )
                    }
                }
            }
        }
        Write-ColorText @(
            @{Text = "Column type updated!"; Color = "Green" }
        )
        Write-Log "Updated column type to '$newColType' for '$($col.Name)' in table '$($Table.Name)'." -Level "INFO"
    }
    return $Table
}

function Edit-Table {
    <#
    .SYNOPSIS
        Edits a table.

    .DESCRIPTION
        Shows menu for editing table.

    .PARAMETER Table
        The table.

    .PARAMETER JunctionTables
        Junction tables.

    .PARAMETER AllTables
        All tables.

    .OUTPUTS
        Modified table.

    .EXAMPLE
        $table = Edit-Table -Table $table -AllTables $allTables
    #>
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
    Write-ColorText @(
        @{Text = "`n--- Editing $($Table.Name) ---"; Color = "Cyan" }
    )

    $oldTableName = $Table.Name

    $editingTable = $true

    while ($editingTable) {
        Write-ColorText @(
            @{Text = "`n--- Editing Table: $($Table.Name) ---"; Color = "Cyan" }
        )
        Write-ColorText @(
            @{Text = "What do you want to edit?"; Color = "Yellow" }
        )
        Write-ColorText @(
            @{Text = "  [0] Table name: $($Table.Name)"; Color = "White" }
        )
        Write-ColorText @(
            @{Text = "  [1] Primary key: $($Table.PrimaryKey)"; Color = "White" }
        )

        for ($i = 0; $i -lt $Table.Columns.Count; $i++) {
            $col = $Table.Columns[$i]
            $pk = if ($col.IsPrimaryKey) { " <- PRIMARY KEY" } else { "" }
            $fk = if ($col.IsForeignKey) { " <- FOREIGN KEY" } else { "" }
            Write-ColorText @(
                @{Text = "  [$($i + 2)] Column: $($col.Name) ($($col.Type))$pk$fk"; Color = "White" }
            )
        }

        Write-ColorText @(
            @{Text = "  [A] Add column"; Color = "Yellow" }
        )
        Write-ColorText @(
            @{Text = "  [R] Remove column"; Color = "Yellow" }
        )
        Write-ColorText @(
            @{Text = "  [D] Done editing this table"; Color = "Green" }
        )

        $choice = (Read-Host "`nYour choice").Trim().ToUpper()

        if ($choice -eq "D") {
            $editingTable = $false
            continue
        }
        if ($choice -eq "A") {
            $Table = Add-TableColumn -Table $Table
            continue
        }
        if ($choice -eq "R") {
            $Table = Remove-TableColumn -Table $Table
            continue
        }
        if ($choice -notmatch '^[ARD]$' -and $choice -notmatch '^\d+$') {
            Write-ColorText @(
                @{Text = "Invalid choice. Please enter a valid number, 'A' to add, 'R' to remove or 'D' to finish."; Color = "Red" }
            )
            continue
        }
        $choiceNum = [int]$choice
        if ($choiceNum -eq 0) {
            $newTableName = (Read-Host "New table name [$($Table.Name)]").Trim()
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
            Write-ColorText @(
                @{Text = "Invalid option number."; Color = "Red" }
            )
        }
    }
    return $Table
}

function Edit-Schema {
    <#
    .SYNOPSIS
        Edits the schema.

    .DESCRIPTION
        Allows editing tables in the schema.

    .PARAMETER Schema
        The schema.

    .OUTPUTS
        Modified schema.

    .EXAMPLE
        $schema = Edit-Schema -Schema $schema
    #>
    param (
        [Parameter(Mandatory)]
        [hashtable]$Schema
    )
    
    $editing = $true
    
    while ($editing) {
        Show-Schema -Schema $Schema
        
        $tableCount = $Schema.Tables.Count
        Write-ColorText @(
            @{Text = "Enter table number to edit (0-$($tableCount - 1)), or D to finish:"; Color = "Yellow" }
        )
        $choice = (Read-Host "Your choice").Trim()
        
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
            Write-ColorText @(
                @{Text = "Invalid choice. Try again."; Color = "Red" }
            )
        }
    }
    
    return $Schema
}

function Confirm-Schema {
    <#
    .SYNOPSIS
        Confirms the schema.

    .DESCRIPTION
        Shows schema and asks for confirmation or editing.

    .PARAMETER Schema
        The schema.

    .OUTPUTS
        Confirmed schema.

    .EXAMPLE
        $schema = Confirm-Schema -Schema $schema
    #>
    param (
        [Parameter(Mandatory)]
        [hashtable]$Schema
    )
    while ($true) {
        Show-Schema -Schema $Schema
        
        Write-ColorText @(
            @{Text = "Do you want to:"; Color = "Yellow" }
        )
        Write-ColorText @(
            @{Text = "  [A] Accept this schema as-is"; Color = "Green" }
        )
        Write-ColorText @(
            @{Text = "  [E] Edit the schema"; Color = "Cyan" }
        )
        Write-ColorText @(
            @{Text = "  [Q] Quit without saving"; Color = "Red" }
        )
        
        $choice = (Read-Host "`nYour choice").Trim().ToUpper()
        
        switch ($choice) {
            "A" { 
                Write-ColorText @(
                    @{Text = "`nSchema accepted!"; Color = "Green" }
                )
                Write-Log "Schema accepted and confirmed." -Level "INFO"
                return $Schema 
            }
            "E" { 
                $Schema = Edit-Schema -Schema $Schema
            }
            "Q" { 
                Write-ColorText @(
                    @{Text = "`nExiting without saving..."; Color = "Red" }
                )
                Write-Log "Schema editing exited without saving." -Level "WARNING"
                return $null 
            }
            default { 
                Write-ColorText @(
                    @{Text = "`nInvalid choice. Please try again."; Color = "Red" }
                )
                return Confirm-Schema -Schema $Schema
            }
        }
    }
}

function Save-SchemaToFile {
    <#
    .SYNOPSIS
        Saves the schema to a file.

    .DESCRIPTION
        Saves the schema with metadata to JSON file.

    .PARAMETER Schema
        The schema.

    .PARAMETER OutputPath
        Path to save the file.

    .EXAMPLE
        Save-SchemaToFile -Schema $schema -OutputPath "output.json"
    #>
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
    
    Write-ColorText @(
        @{Text = "`nSchema saved to: $OutputPath"; Color = "Green" }
    )
    Write-Log "Schema saved to file: $OutputPath" -Level "INFO"
}

