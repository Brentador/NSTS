function ConvertTo-SqlStatements {
    param (
        [Parameter(Mandatory = $true)]$Schema
    )
    
    $sqlStatements = @()
    
    foreach ($table in $Schema.Tables) {
        $createTable = "CREATE TABLE $($table.Name) (`n"
        
        $columnDefinitions = @()
        foreach ($column in $table.Columns) {
            $def = "    $($column.Name) $($column.Type)"
            
            if ($column.IsPrimaryKey) {
                $def += " PRIMARY KEY"
            }
            
            $columnDefinitions += $def
        }
        
        $createTable += ($columnDefinitions -join ",`n")
        $createTable += "`n);"
        
        $sqlStatements += $createTable
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
    }
    
    return $sqlStatements
}

Export-ModuleMember -Function ConvertTo-SqlStatements