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

function Edit-Table {
    param (
        [Parameter(Mandatory)]
        [hashtable]$Table,
        [Parameter(Mandatory)]
        [array]$JunctionTables,
        [Parameter(Mandatory)]
        [array]$AllTables
    )

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

        Write-Host "  [D] Done editing this table" -ForegroundColor Green

        $choice = Read-Host "`nYour choice"

        if ($choice -eq "D" -or $choice -eq "d") {
            $editingTable = $false
            continue
        }

        if ($choice -notmatch '^\d+$') {
            Write-Host "Invalid choice. Please enter a valid number or 'D' to finish." -ForegroundColor Red
            continue
        }

        $choiceNum = [int]$choice

        if ($choiceNum -eq 0) {
            $newTableName = Read-Host "New table name [$($Table.Name)]"
            if ($newTableName) {
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

                $oldTableName = $newTableName
                Write-Host "Table name updated to $newTableName" -ForegroundColor Green
            }
        }
        elseif ($choiceNum -eq 1) {
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
            }

        }
        elseif ($choiceNum -ge 2 -and $choiceNum -lt ($Table.Columns.Count + 2)) {
            $colIndex = $choiceNum - 2
            $col = $Table.Columns[$colIndex]
            Write-Host "`nEditing column: $($col.Name)" -ForegroundColor Cyan

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
            }

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
            }
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
        
        Write-Host "What do you want to edit?" -ForegroundColor Yellow
        Write-Host "  [T] Edit a table (choose by number)" -ForegroundColor Cyan
        Write-Host "  [D] Done editing" -ForegroundColor Green
        
        $choice = Read-Host "`nYour choice"
        
        switch ($choice.ToUpper()) {
            "T" {
                if ($Schema.Tables.Count -eq 0) {
                    Write-Host "No tables to edit." -ForegroundColor Red
                }
                else {
                    $tableNum = Read-Host "Which table? (0-$($Schema.Tables.Count - 1))"
                    if ($tableNum -match '^\d+$' -and [int]$tableNum -lt $Schema.Tables.Count) {
                        $Schema.Tables[[int]$tableNum] = Edit-Table `
                            -Table $Schema.Tables[[int]$tableNum] `
                            -JunctionTables $Schema.JunctionTables `
                            -AllTables $Schema.Tables
                    }
                    else {
                        Write-Host "Invalid table number." -ForegroundColor Red
                    }
                }
            }
            "D" {
                $editing = $false
            }
            default {
                Write-Host "Invalid choice. Try again." -ForegroundColor Red
            }
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
            return $Schema 
        }
        "E" { 
            $editedSchema = Edit-Schema -Schema $Schema
            return Confirm-Schema -Schema $editedSchema
        }
        "Q" { 
            Write-Host "`nExiting without saving..." -ForegroundColor Red
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
    
    $schemaWithMetadata = @{
        schema        = $Schema
        validated     = $true
        validatedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        version       = "1.0"
    }
    
    $json = $schemaWithMetadata | ConvertTo-Json -Depth 10
    $json | Out-File -FilePath $OutputPath -Encoding UTF8
    
    Write-Host "`nSchema saved to: $OutputPath" -ForegroundColor Green
}

Export-ModuleMember -Function Show-Schema, Confirm-Schema, Save-SchemaToFile