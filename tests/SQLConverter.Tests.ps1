BeforeAll {
    . "$PSScriptRoot\..\src\Private\Logger.ps1"
    . "$PSScriptRoot\..\src\Private\SQLConverter.ps1"

    Mock Write-Log { }
}

Describe "ConvertTo-SqlStatements - Basic Tables" { 
    It "Generates CREATE TABLE with primary key" {
        $schema = @{
            Tables = @(
                @{
                    Name       = "users"
                    PrimaryKey = "id"
                    Columns    = @(
                        @{ Name = "id"; Type = "INT"; IsPrimaryKey = $true }
                        @{ Name = "name"; Type = "VARCHAR(255)"; IsPrimaryKey = $false }
                    )
                }
            )
            JunctionTables = @()
        }
        
        $result = ConvertTo-SqlStatements -Schema $schema
        $sql = @($result)
        
        $sql | Should -Not -BeNullOrEmpty
        $sql.Count | Should -Be 1
        $sql[0] | Should -Match "CREATE TABLE users"
        $sql[0] | Should -Match "id INT PRIMARY KEY"
        $sql[0] | Should -Match "name VARCHAR\(255\)"
    }
    
    It "Generates multiple tables in correct order" {
        $schema = @{
            Tables = @(
                @{
                    Name = "users"
                    PrimaryKey = "id"
                    Columns = @(
                        @{ Name = "id"; Type = "INT"; IsPrimaryKey = $true }
                    )
                }
                @{
                    Name = "posts"
                    PrimaryKey = "post_id"
                    Columns = @(
                        @{ Name = "post_id"; Type = "INT"; IsPrimaryKey = $true }
                    )
                }
            )
            JunctionTables = @()
        }
        
        $result = ConvertTo-SqlStatements -Schema $schema
        $sql = @($result)
        
        $sql.Count | Should -Be 2
        $sql[0] | Should -Match "CREATE TABLE users"
        $sql[1] | Should -Match "CREATE TABLE posts"
    }
    
    It "Handles table with multiple columns" {
        $schema = @{
            Tables = @(
                @{
                    Name = "employees"
                    PrimaryKey = "emp_id"
                    Columns = @(
                        @{ Name = "emp_id"; Type = "INT"; IsPrimaryKey = $true }
                        @{ Name = "first_name"; Type = "VARCHAR(100)"; IsPrimaryKey = $false }
                        @{ Name = "last_name"; Type = "VARCHAR(100)"; IsPrimaryKey = $false }
                        @{ Name = "email"; Type = "VARCHAR(255)"; IsPrimaryKey = $false }
                        @{ Name = "hire_date"; Type = "DATE"; IsPrimaryKey = $false }
                    )
                }
            )
            JunctionTables = @()
        }
        
        $result = ConvertTo-SqlStatements -Schema $schema
        $sql = @($result)
        
        $sql[0] | Should -Match "emp_id INT PRIMARY KEY"
        $sql[0] | Should -Match "first_name VARCHAR\(100\)"
        $sql[0] | Should -Match "last_name VARCHAR\(100\)"
        $sql[0] | Should -Match "email VARCHAR\(255\)"
        $sql[0] | Should -Match "hire_date DATE"
    }
}

Describe "ConvertTo-SqlStatements - Junction Tables" {
    
    It "Generates junction table with composite primary key" {
        $schema = @{
            Tables = @()
            JunctionTables = @(
                @{
                    TableName = "user_roles"
                    Table1 = "users"
                    Table2 = "roles"
                    Table1FK = "user_id"
                    Table2FK = "role_id"
                    Columns = @(
                        @{ Name = "user_id"; Type = "INT" }
                        @{ Name = "role_id"; Type = "INT" }
                    )
                }
            )
        }
        
        $result = ConvertTo-SqlStatements -Schema $schema
        $sql = @($result)
        
        $sql.Count | Should -Be 1
        $sql[0] | Should -Match "CREATE TABLE user_roles"
        $sql[0] | Should -Match "user_id INT"
        $sql[0] | Should -Match "role_id INT"
        $sql[0] | Should -Match "PRIMARY KEY \(user_id, role_id\)"
    }
    
    It "Generates foreign key constraints for junction table" {
        $schema = @{
            Tables = @()
            JunctionTables = @(
                @{
                    TableName = "student_courses"
                    Table1 = "students"
                    Table2 = "courses"
                    Table1FK = "student_id"
                    Table2FK = "course_id"
                    Columns = @(
                        @{ Name = "student_id"; Type = "INT" }
                        @{ Name = "course_id"; Type = "INT" }
                    )
                }
            )
        }
        
        $result = ConvertTo-SqlStatements -Schema $schema
        $sql = @($result)
        
        $sql[0] | Should -Match "FOREIGN KEY \(student_id\) REFERENCES students\(student_id\)"
        $sql[0] | Should -Match "FOREIGN KEY \(course_id\) REFERENCES courses\(course_id\)"
    }
    
    It "Handles multiple junction tables" {
        $schema = @{
            Tables = @()
            JunctionTables = @(
                @{
                    TableName = "user_roles"
                    Table1 = "users"
                    Table2 = "roles"
                    Table1FK = "user_id"
                    Table2FK = "role_id"
                    Columns = @(
                        @{ Name = "user_id"; Type = "INT" }
                        @{ Name = "role_id"; Type = "INT" }
                    )
                }
                @{
                    TableName = "user_permissions"
                    Table1 = "users"
                    Table2 = "permissions"
                    Table1FK = "user_id"
                    Table2FK = "permission_id"
                    Columns = @(
                        @{ Name = "user_id"; Type = "INT" }
                        @{ Name = "permission_id"; Type = "INT" }
                    )
                }
            )
        }
        
        $result = ConvertTo-SqlStatements -Schema $schema
        $sql = @($result)
        
        $sql.Count | Should -Be 2
        $sql[0] | Should -Match "CREATE TABLE user_roles"
        $sql[1] | Should -Match "CREATE TABLE user_permissions"
    }
}

Describe "ConvertTo-SqlStatements - Mixed Tables and Junctions" {
    
    It "Generates both regular and junction tables" {
        $schema = @{
            Tables = @(
                @{
                    Name = "users"
                    PrimaryKey = "id"
                    Columns = @(
                        @{ Name = "id"; Type = "INT"; IsPrimaryKey = $true }
                        @{ Name = "username"; Type = "VARCHAR(50)"; IsPrimaryKey = $false }
                    )
                }
                @{
                    Name = "roles"
                    PrimaryKey = "id"
                    Columns = @(
                        @{ Name = "id"; Type = "INT"; IsPrimaryKey = $true }
                        @{ Name = "role_name"; Type = "VARCHAR(50)"; IsPrimaryKey = $false }
                    )
                }
            )
            JunctionTables = @(
                @{
                    TableName = "user_roles"
                    Table1 = "users"
                    Table2 = "roles"
                    Table1FK = "user_id"
                    Table2FK = "role_id"
                    Columns = @(
                        @{ Name = "user_id"; Type = "INT" }
                        @{ Name = "role_id"; Type = "INT" }
                    )
                }
            )
        }
        
        $result = ConvertTo-SqlStatements -Schema $schema
        $sql = @($result)
        
        $sql.Count | Should -Be 3
        $sql[0] | Should -Match "CREATE TABLE users"
        $sql[1] | Should -Match "CREATE TABLE roles"
        $sql[2] | Should -Match "CREATE TABLE user_roles"
    }
}

Describe "ConvertTo-SqlStatements - SQL Syntax Validation" {
    
    It "Uses correct SQL formatting with newlines and indentation" {
        $schema = @{
            Tables = @(
                @{
                    Name = "products"
                    PrimaryKey = "id"
                    Columns = @(
                        @{ Name = "id"; Type = "INT"; IsPrimaryKey = $true }
                        @{ Name = "name"; Type = "VARCHAR(100)"; IsPrimaryKey = $false }
                    )
                }
            )
            JunctionTables = @()
        }
        
        $result = ConvertTo-SqlStatements -Schema $schema
        $sql = @($result)
        
        $sql[0] | Should -Match "CREATE TABLE products \(`n"
        $sql[0] | Should -Match "    id INT PRIMARY KEY"
        $sql[0] | Should -Match "`n\);"
    }
    
    It "Separates columns with commas and newlines" {
        $schema = @{
            Tables = @(
                @{
                    Name = "orders"
                    PrimaryKey = "id"
                    Columns = @(
                        @{ Name = "id"; Type = "INT"; IsPrimaryKey = $true }
                        @{ Name = "total"; Type = "DECIMAL(10,2)"; IsPrimaryKey = $false }
                        @{ Name = "status"; Type = "VARCHAR(20)"; IsPrimaryKey = $false }
                    )
                }
            )
            JunctionTables = @()
        }
        
        $result = ConvertTo-SqlStatements -Schema $schema
        $sql = @($result)
        
        $sql[0] | Should -Match "id INT PRIMARY KEY,`n"
        $sql[0] | Should -Match "total DECIMAL\(10,2\),`n"
        $sql[0] | Should -Match "status VARCHAR\(20\)`n"
    }
    
    It "Ends statements with semicolon" {
        $schema = @{
            Tables = @(
                @{
                    Name = "test"
                    PrimaryKey = "id"
                    Columns = @(@{ Name = "id"; Type = "INT"; IsPrimaryKey = $true })
                }
            )
            JunctionTables = @()
        }
        
        $result = ConvertTo-SqlStatements -Schema $schema
        $sql = @($result)
        
        $sql[0] | Should -Match "\);$"
    }
}

Describe "ConvertTo-SqlStatements - Data Type Support" {
    
    It "Handles various SQL data types" {
        $schema = @{
            Tables = @(
                @{
                    Name = "test_types"
                    PrimaryKey = "id"
                    Columns = @(
                        @{ Name = "id"; Type = "INT"; IsPrimaryKey = $true }
                        @{ Name = "description"; Type = "TEXT"; IsPrimaryKey = $false }
                        @{ Name = "price"; Type = "DECIMAL(10,2)"; IsPrimaryKey = $false }
                        @{ Name = "is_active"; Type = "BOOLEAN"; IsPrimaryKey = $false }
                        @{ Name = "created_at"; Type = "TIMESTAMP"; IsPrimaryKey = $false }
                    )
                }
            )
            JunctionTables = @()
        }
        
        $result = ConvertTo-SqlStatements -Schema $schema
        $sql = @($result)
        
        $sql[0] | Should -Match "description TEXT"
        $sql[0] | Should -Match "price DECIMAL\(10,2\)"
        $sql[0] | Should -Match "is_active BOOLEAN"
        $sql[0] | Should -Match "created_at TIMESTAMP"
    }
}

Describe "ConvertTo-SqlStatements - Edge Cases" {
    
    It "Handles empty table list" {
        $schema = @{
            Tables = @()
            JunctionTables = @()
        }
        
        $result = ConvertTo-SqlStatements -Schema $schema
        $sql = @($result)
        
        $sql.Count | Should -Be 0
    }
}