function Show-Schema {
    param (
        [Parameter(Mandatory)]
        [hashtable]$Schema
    )
    
    Write-Host "`n==================== DETECTED SCHEMA ====================" -ForegroundColor Cyan
    Write-Host "`n[MAIN TABLE]" -ForegroundColor Green
    Write-Host "  Table: $($Schema.MainTable.Name) (PK: $($Schema.MainTable.PrimaryKey))" -ForegroundColor White
    Write-Host "  Columns:" -ForegroundColor Gray
    foreach ($col in $Schema.MainTable.Columns) {
        $pk = if ($col.IsPrimaryKey) { " <- PRIMARY KEY" } else { "" }
        Write-Host "    - $($col.Name) ($($col.Type))$pk" -ForegroundColor White
    }
    
    Write-Host "`n[RELATED TABLES]" -ForegroundColor Yellow
    $tableIndex = 0
    foreach ($table in $Schema.RelatedTables) {
        Write-Host "  [$tableIndex] Table: $($table.TableName) (PK: $($table.PrimaryKey))" -ForegroundColor White
        Write-Host "      Columns:" -ForegroundColor Gray
        foreach ($col in $table.Columns) {
            $pk = if ($col.IsPrimaryKey) { " <- PRIMARY KEY" } else { "" }
            Write-Host "        - $($col.Name) ($($col.Type))$pk" -ForegroundColor White
        }
        $tableIndex++
    }
    
    Write-Host "`n[RELATIONSHIPS (Junction Tables)]" -ForegroundColor Magenta
    foreach ($junction in $Schema.JunctionTables) {
        Write-Host "  $($junction.TableName)" -ForegroundColor White
        Write-Host "    Links: $($junction.MainTableFK) -> $($junction.RelatedTableFK)" -ForegroundColor Gray
    }
    
    Write-Host "`n========================================================`n" -ForegroundColor Cyan
}

function Edit-MainTable {
    param (
        [Parameter(Mandatory)]
        [hashtable]$MainTable,
        
        [Parameter(Mandatory)]
        [array]$JunctionTables
    )
    
    Write-Host "`n--- Editing Main Table: $($MainTable.Name) ---" -ForegroundColor Cyan
    
    $oldTableName = $MainTable.Name
    $oldPK = $MainTable.PrimaryKey
    
    $newTableName = Read-Host "Table name [$($MainTable.Name)]"
    if ($newTableName) { 
        $MainTable.Name = $newTableName 
        
        foreach ($junction in $JunctionTables) {
            $junction.TableName = $junction.TableName -replace "^$oldTableName", $newTableName
        }
    }
    
    Write-Host "`nEdit columns? [Y/N]" -ForegroundColor Yellow
    $editCols = Read-Host
    
    if ($editCols -eq "Y" -or $editCols -eq "y") {
        for ($i = 0; $i -lt $MainTable.Columns.Count; $i++) {
            $col = $MainTable.Columns[$i]
            $pkMarker = if ($col.IsPrimaryKey) { " <- CURRENT PK" } else { "" }
            Write-Host "`n  Column $($i + 1): $($col.Name) ($($col.Type))$pkMarker" -ForegroundColor White
            
            $newColName = Read-Host "    New column name [keep: $($col.Name)]"
            if ($newColName) { 
                if ($col.IsPrimaryKey) {
                    $oldPK = $col.Name
                    $MainTable.PrimaryKey = $newColName
                    
                    foreach ($junction in $JunctionTables) {
                        if ($junction.MainTableFK -eq $oldPK) {
                            $junction.MainTableFK = $newColName
                            
                            $junctionCol = $junction.Columns | Where-Object { $_.Name -eq $oldPK }
                            if ($junctionCol) {
                                $junctionCol.Name = $newColName
                            }
                        }
                    }
                }
                $col.Name = $newColName 
            }
            
            $newColType = Read-Host "    New data type [keep: $($col.Type)]"
            if ($newColType) { $col.Type = $newColType }
        }
    }
    
    Write-Host "`nChange primary key? [Y/N]" -ForegroundColor Yellow
    $changePK = Read-Host
    
    if ($changePK -eq "Y" -or $changePK -eq "y") {
        Write-Host "`nAvailable columns:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $MainTable.Columns.Count; $i++) {
            $col = $MainTable.Columns[$i]
            $current = if ($col.IsPrimaryKey) { " <- CURRENT" } else { "" }
            Write-Host "  [$i] $($col.Name)$current" -ForegroundColor White
        }
        
        $pkChoice = Read-Host "`nSelect column number for primary key [keep: $($MainTable.PrimaryKey)]"
        
        if ($pkChoice -match '^\d+$' -and [int]$pkChoice -lt $MainTable.Columns.Count) {
            foreach ($col in $MainTable.Columns) {
                $col.IsPrimaryKey = $false
            }
            
            $newPKCol = $MainTable.Columns[[int]$pkChoice]
            $newPKCol.IsPrimaryKey = $true
            $oldPK = $MainTable.PrimaryKey
            $MainTable.PrimaryKey = $newPKCol.Name
            
            foreach ($junction in $JunctionTables) {
                if ($junction.MainTableFK -eq $oldPK) {
                    $junction.MainTableFK = $newPKCol.Name
                    
                    $junctionCol = $junction.Columns | Where-Object { $_.Name -eq $oldPK }
                    if ($junctionCol) {
                        $junctionCol.Name = $newPKCol.Name
                    }
                }
            }
            
            Write-Host "Primary key set to: $($MainTable.PrimaryKey)" -ForegroundColor Green
            Write-Host "Junction tables updated automatically" -ForegroundColor Green
        }
    }
    
    return $MainTable
}

function Edit-RelatedTable {
    param (
        [Parameter(Mandatory)]
        [hashtable]$Table,
        
        [Parameter(Mandatory)]
        [array]$JunctionTables,
        
        [Parameter(Mandatory)]
        [hashtable]$MainTable
    )
    
    Write-Host "`n--- Editing Related Table: $($Table.TableName) ---" -ForegroundColor Cyan
    
    $oldTableName = $Table.TableName
    $oldPK = $Table.PrimaryKey
    
    $newTableName = Read-Host "Table name [$($Table.TableName)]"
    if ($newTableName) { 
        $Table.TableName = $newTableName 
        
        foreach ($junction in $JunctionTables) {
            if ($junction.TableName -match "_$oldTableName$") {
                $junction.TableName = $junction.TableName -replace "_$oldTableName$", "_$newTableName"
            }
        }
        
        if ($Table.RelationType -eq "OneToMany") {
            $fkCol = $MainTable.Columns | Where-Object { $_.ReferencesTable -eq $oldTableName }
            if ($fkCol) {
                $fkCol.ReferencesTable = $newTableName
            }
        }
    }
    
    Write-Host "`nEdit columns? [Y/N]" -ForegroundColor Yellow
    $editCols = Read-Host
    
    if ($editCols -eq "Y" -or $editCols -eq "y") {
        for ($i = 0; $i -lt $Table.Columns.Count; $i++) {
            $col = $Table.Columns[$i]
            $pkMarker = if ($col.IsPrimaryKey) { " <- CURRENT PK" } else { "" }
            Write-Host "`n  Column $($i + 1): $($col.Name) ($($col.Type))$pkMarker" -ForegroundColor White
            
            $newColName = Read-Host "    New column name [keep: $($col.Name)]"
            if ($newColName) { 
                if ($col.IsPrimaryKey) {
                    $oldPK = $col.Name
                    $Table.PrimaryKey = $newColName
                    
                    foreach ($junction in $JunctionTables) {
                        if ($junction.RelatedTableFK -eq $oldPK) {
                            $junction.RelatedTableFK = $newColName
                            
                            $junctionCol = $junction.Columns | Where-Object { $_.Name -eq $oldPK }
                            if ($junctionCol) {
                                $junctionCol.Name = $newColName
                            }
                        }
                    }
                    
                    if ($Table.RelationType -eq "OneToMany") {
                        $fkCol = $MainTable.Columns | Where-Object { $_.ReferencesColumn -eq $oldPK }
                        if ($fkCol) {
                            $fkCol.ReferencesColumn = $newColName
                        }
                    }
                }
                $col.Name = $newColName 
            }
            
            $newColType = Read-Host "    New data type [keep: $($col.Type)]"
            if ($newColType) { $col.Type = $newColType }
        }
    }
    
    Write-Host "`nChange primary key? [Y/N]" -ForegroundColor Yellow
    $changePK = Read-Host
    
    if ($changePK -eq "Y" -or $changePK -eq "y") {
        Write-Host "`nAvailable columns:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $Table.Columns.Count; $i++) {
            $col = $Table.Columns[$i]
            $current = if ($col.IsPrimaryKey) { " <- CURRENT" } else { "" }
            Write-Host "  [$i] $($col.Name)$current" -ForegroundColor White
        }
        
        $pkChoice = Read-Host "`nSelect column number for primary key [keep: $($Table.PrimaryKey)]"
        
        if ($pkChoice -match '^\d+$' -and [int]$pkChoice -lt $Table.Columns.Count) {
            foreach ($col in $Table.Columns) {
                $col.IsPrimaryKey = $false
            }
            
            $newPKCol = $Table.Columns[[int]$pkChoice]
            $newPKCol.IsPrimaryKey = $true
            $oldPK = $Table.PrimaryKey
            $Table.PrimaryKey = $newPKCol.Name
            
            foreach ($junction in $JunctionTables) {
                if ($junction.RelatedTableFK -eq $oldPK) {
                    $junction.RelatedTableFK = $newPKCol.Name
                    $junctionCol = $junction.Columns | Where-Object { $_.Name -eq $oldPK }
                    if ($junctionCol) {
                        $junctionCol.Name = $newPKCol.Name
                    }
                }
            }
            
            if ($Table.RelationType -eq "OneToMany") {
                $fkCol = $MainTable.Columns | Where-Object { $_.ReferencesColumn -eq $oldPK }
                if ($fkCol) {
                    $fkCol.ReferencesColumn = $newPKCol.Name
                }
            }
            
            Write-Host "Primary key set to: $($Table.PrimaryKey)" -ForegroundColor Green
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
        Write-Host "  [M] Main table" -ForegroundColor Cyan
        Write-Host "  [R] Related table (choose by number)" -ForegroundColor Cyan
        Write-Host "  [D] Done editing" -ForegroundColor Green
        
        $choice = Read-Host "`nYour choice"
        
        switch ($choice.ToUpper()) {
            "M" {
                $Schema.MainTable = Edit-MainTable -MainTable $Schema.MainTable -JunctionTables $Schema.JunctionTables
            }
            "R" {
                if ($Schema.RelatedTables.Count -eq 0) {
                    Write-Host "No related tables to edit." -ForegroundColor Red
                } else {
                    $tableNum = Read-Host "Which table? (0-$($Schema.RelatedTables.Count - 1))"
                    if ($tableNum -match '^\d+$' -and [int]$tableNum -lt $Schema.RelatedTables.Count) {
                        $Schema.RelatedTables[[int]$tableNum] = Edit-RelatedTable `
                            -Table $Schema.RelatedTables[[int]$tableNum] `
                            -JunctionTables $Schema.JunctionTables `
                            -MainTable $Schema.MainTable
                    } else {
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
        schema = $Schema
        validated = $true
        validatedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        version = "1.0"
    }
    
    $json = $schemaWithMetadata | ConvertTo-Json -Depth 10
    $json | Out-File -FilePath $OutputPath -Encoding UTF8
    
    Write-Host "`nSchema saved to: $OutputPath" -ForegroundColor Green
}

Export-ModuleMember -Function Show-Schema, Confirm-Schema, Save-SchemaToFile