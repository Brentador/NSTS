function ConvertTo-SqlStatements {
    param (
        [Parameter(Mandatory = $true)]$Schema
    )
    
    Write-Log "Starting SQL conversion for schema with $($Schema.Tables.Count) tables and $($Schema.JunctionTables.Count) junction tables." -Level "INFO"
    $sqlStatements = @()
    
    foreach ($table in $Schema.Tables) {
        $createTable = "CREATE TABLE $($table.Name) (`n"

        $columnDefinitions = @()
        $foreignKeyDefs = @()
        foreach ($column in $table.Columns) {
            $def = "    $($column.Name) $($column.Type)"
            if ($column.IsPrimaryKey) {
                $def += " PRIMARY KEY"
            }
            $columnDefinitions += $def

            if ($column.IsForeignKey -and $column.ReferencesTable -and $column.ReferencesColumn) {
                $foreignKeyDefs += "    FOREIGN KEY ($($column.Name)) REFERENCES $($column.ReferencesTable)($($column.ReferencesColumn))"
            }
        }

        if ($table.ForeignKeys) {
            foreach ($fk in $table.ForeignKeys) {
                $foreignKeyDefs += "    FOREIGN KEY ($($fk.Column)) REFERENCES $($fk.ReferenceTable)($($fk.ReferenceColumn))"
            }
        }

        $createTable += ($columnDefinitions + $foreignKeyDefs -join ",`n")
        $createTable += "`n);"

        $sqlStatements += $createTable
        Write-Log "Generated CREATE TABLE statement for '$($table.Name)'." -Level "INFO"
    }
    
    foreach ($junction in $Schema.JunctionTables) {
        $createTable = "CREATE TABLE $($junction.TableName) (`n"
        
        $columnDefinitions = @()
        foreach ($column in $junction.Columns) {
            $columnDefinitions += "    $($column.Name) $($column.Type)"
        }
        
        $pkColumns = $junction.Columns.Name -join ", "
        $columnDefinitions += "    PRIMARY KEY ($pkColumns)"
        
        $columnDefinitions += "    FOREIGN KEY ($($junction.Table1FK)) REFERENCES $($junction.Table1)($($junction.Table1FK))"
        $columnDefinitions += "    FOREIGN KEY ($($junction.Table2FK)) REFERENCES $($junction.Table2)($($junction.Table2FK))"
        
        $createTable += ($columnDefinitions -join ",`n")
        $createTable += "`n);"
        
        $sqlStatements += $createTable
        Write-Log "Generated CREATE TABLE statement for junction table '$($junction.TableName)'." -Level "INFO"
    }
    
    Write-Log "SQL conversion completed, generated $($sqlStatements.Count) statements." -Level "INFO"
    return $sqlStatements
}

