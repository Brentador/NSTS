BeforeAll {
    Import-Module "$PSScriptRoot\..\src\NSTS.psm1" -Force
    Initialize-Logger -LogDirectory "$PSScriptRoot\..\tests\logs" -LogPrefix "test"
}



Describe "Get-PrimaryKeyField" {
    It "Detects 'id' as the primary key field via JsonToSchemaFromObject" {
        $json = @(
            [PSCustomObject]@{ id = 1; name = "Alice" },
            [PSCustomObject]@{ id = 2; name = "Bob" }
        )
        $schema = JsonToSchemaFromObject -JsonData $json
        $pk = $schema.Tables[0].PrimaryKey
        $pk | Should -Be 'id'
    }

    It "Detects 'userId' as the primary key field" {
        $json = @(
            [PSCustomObject]@{ userId = 1; name = "Alice" },
            [PSCustomObject]@{ userId = 2; name = "Bob" }
        )
        $schema = JsonToSchemaFromObject -JsonData $json
        $pk = $schema.Tables[0].PrimaryKey
        $pk | Should -Be 'userId'
    }

    It "Auto-generates 'id' as the primary key field when no explicit key is present" {
        $json = @(
            [PSCustomObject]@{ name = "Alice"; age = 30 },
            [PSCustomObject]@{ name = "Bob"; age = 25 }
        )
        $schema = JsonToSchemaFromObject -JsonData $json
        $pk = $schema.Tables[0].PrimaryKey
        $pk | Should -Be 'id'
    }

    It "Detects '_id' suffix as the primary key" {
        $json = @(
            [PSCustomObject]@{ test_id = 1; name = "Alice" },
            [PSCustomObject]@{ test_id = 2; name = "Bob" }
        )
        $schema = JsonToSchemaFromObject -JsonData $json
        $pk = $schema.Tables[0].PrimaryKey
        $pk | Should -Be 'test_id'
    }
}

Describe "Get-MainTableName" {
    It "Generates table name from 'userId'" {
        $json = @(
            [PSCustomObject]@{ userId = 1; name = "Alice" },
            [PSCustomObject]@{ userId = 2; name = "Bob" }
        )
        $schema = JsonToSchemaFromObject -JsonData $json
        $tableName = $schema.Tables[0].Name
        $tableName | Should -Be "users"
    }

    It "Handles single character base names 'uId'" {
        $json = @(
            [PSCustomObject]@{ uId = 1; name = "Alice" },
            [PSCustomObject]@{ uId = 2; name = "Bob" }
        )
        $schema = JsonToSchemaFromObject -JsonData $json
        $tableName = $schema.Tables[0].Name
        $tableName | Should -Be "u_records"
    }

    It "Returns placeholder for unknown primary key field" {
        $json = @(
            [PSCustomObject]@{ unknown = 1; name = "Alice" },
            [PSCustomObject]@{ unknown = 2; name = "Bob" }
        )
        $schema = JsonToSchemaFromObject -JsonData $json
        $tableName = $schema.Tables[0].Name
        $tableName | Should -Be "[REPLACE WITH TABLE NAME]"
    }
}

Describe "Get-SimpleValue" {
    It "Returns correct Name and IsPrimaryKey flags" {
        $json = @(
            [PSCustomObject]@{ id = 1; name = "Alice"; age = 30 },
            [PSCustomObject]@{ id = 2; name = "Bob"; age = 25 }
        )
        $schema = JsonToSchemaFromObject -JsonData $json

        $idColumn = $schema.Tables[0].Columns | Where-Object { $_.Name -eq 'id' }
        $idColumn.Name | Should -Be 'id'
        $idColumn.IsPrimaryKey | Should -Be $true

        $nameColumn = $schema.Tables[0].Columns | Where-Object { $_.Name -eq 'name' }
        $nameColumn.Name | Should -Be 'name'
        $nameColumn.IsPrimaryKey | Should -Be $false

        $ageColumn = $schema.Tables[0].Columns | Where-Object { $_.Name -eq 'age' }
        $ageColumn.Name | Should -Be 'age'
        $ageColumn.IsPrimaryKey | Should -Be $false
    }

    It "Returns correct Type for basic types (INT, VARCHAR(255), FLOAT, BOOLEAN, TEXT) via Get-SqlType" {
        $json = @(
            [PSCustomObject]@{
                id = 1
                name = "Alice"
                age = 30
                salary = 50000.50
                isActive = $true
                description = "a" * 300
            }
        )
        $schema = JsonToSchemaFromObject -JsonData $json

        ($schema.Tables[0].Columns | Where-Object { $_.Name -eq 'id' }).Type | Should -Be "INT"
        ($schema.Tables[0].Columns | Where-Object { $_.Name -eq 'name' }).Type | Should -Be "VARCHAR(255)"
        ($schema.Tables[0].Columns | Where-Object { $_.Name -eq 'age' }).Type | Should -Be "INT"
        ($schema.Tables[0].Columns | Where-Object { $_.Name -eq 'salary' }).Type | Should -Be "FLOAT"
        ($schema.Tables[0].Columns | Where-Object { $_.Name -eq 'isActive' }).Type | Should -Be "BOOLEAN"
        ($schema.Tables[0].Columns | Where-Object { $_.Name -eq 'description' }).Type | Should -Be "TEXT"
    }

    It "Handles PrimaryKeyField and autoGenerateId combinations properly" {
        $jsonWithId = @(
            [PSCustomObject]@{ id = 1; name = "Alice" }
        )
        $schema1 = JsonToSchemaFromObject -JsonData $jsonWithId
        ($schema1.Tables[0].Columns | Where-Object { $_.Name -eq 'id' }).IsPrimaryKey | Should -Be $true

        $jsonNoId = @(
            [PSCustomObject]@{ name = "Alice"; age = 30 }
        )
        $schema2 = JsonToSchemaFromObject -JsonData $jsonNoId
        $idColumn = $schema2.Tables[0].Columns | Where-Object { $_.Name -eq 'id' }
        $idColumn.IsPrimaryKey | Should -Be $true
        $idColumn.Type | Should -Be "INT"

        ($schema2.Tables[0].Columns | Where-Object { $_.Name -eq 'name' }).IsPrimaryKey | Should -Be $false
    }
}

Describe "Add-SimpleArray" {
    It "Creates a related table for a simple array" {
        $json = @(
            [PSCustomObject]@{ id = 1; name = "Alice"; tags = @("Admin", "Tester") },
            [PSCustomObject]@{ id = 2; name = "Bob"; tags = @("User") }
        )
        $schema = JsonToSchemaFromObject -JsonData $json

        $relatedTable = $schema.Tables | Where-Object { $_.Name -eq 'tags' }
        $relatedTable | Should -Not -BeNullOrEmpty
        $relatedTable.RelationType | Should -Be "ManyToMany"
        $relatedTable.PrimaryKey | Should -Be "tags_id"
    }

    It "Creates a junction table for the parent-child relationship" {
        $json = @(
            [PSCustomObject]@{ id = 1; name = "Alice"; tags = @("Admin", "Tester") },
            [PSCustomObject]@{ id = 2; name = "Bob"; tags = @("User") }
        )
        $schema = JsonToSchemaFromObject -JsonData $json

        $junctionTable = $schema.JunctionTables | Where-Object { $_.TableName -eq '[REPLACE WITH TABLE NAME]_tags' }
        $junctionTable | Should -Not -BeNullOrEmpty
        $junctionTable.Table1 | Should -Be "[REPLACE WITH TABLE NAME]"
        $junctionTable.Table1FK | Should -Be "id"
        $junctionTable.Table2 | Should -Be "tags"
        $junctionTable.Table2FK | Should -Be "tags_id"
    }

    It "Correct column types in the related table" {
        $json = @(
            [PSCustomObject]@{ id = 1; name = "Alice"; tags = @("Admin", "Tester") }
        )
        $schema = JsonToSchemaFromObject -JsonData $json

        $relatedTable = $schema.Tables | Where-Object { $_.Name -eq 'tags' }
        $pkColumn = $relatedTable.Columns | Where-Object { $_.Name -eq 'tags_id' }
        $pkColumn.Type | Should -Be "INT"
        $pkColumn.IsPrimaryKey | Should -Be $true

        $valueColumn = $relatedTable.Columns | Where-Object { $_.Name -eq 'tags_value' }
        $valueColumn.Type | Should -Be "VARCHAR(255)"
        $valueColumn.IsPrimaryKey | Should -Be $false
    }

    It "Correct foreign key type in the junction table (INT if autoGenerateId else Get-SqlType of parent PK)" {
        $jsonWithId = @(
            [PSCustomObject]@{ id = 1; name = "Alice"; tags = @("Admin") }
        )
        $schema1 = JsonToSchemaFromObject -JsonData $jsonWithId
        $junction1 = $schema1.JunctionTables | Where-Object { $_.TableName -eq '[REPLACE WITH TABLE NAME]_tags' }
        ($junction1.Columns | Where-Object { $_.Name -eq 'id' }).Type | Should -Be "INT"

        $jsonNoId = @(
            [PSCustomObject]@{ name = "Alice"; tags = @("Admin") }
        )
        $schema2 = JsonToSchemaFromObject -JsonData $jsonNoId
        $junction2 = $schema2.JunctionTables | Where-Object { $_.TableName -eq '[REPLACE WITH TABLE NAME]_tags' }
        ($junction2.Columns | Where-Object { $_.Name -eq 'id' }).Type | Should -Be "INT"
    }
}

Describe "Add-ObjectArray" {
    It "Routes to Add-OneToManyObjectArray for OneToMany relationships" {
        $json = @(
            [PSCustomObject]@{
                id = 1
                name = "Alice"
                projects = @(
                    [PSCustomObject]@{ project_id = 100; title = "ProjA" }
                )
            }
        )
        $schema = JsonToSchemaFromObject -JsonData $json

        $projectsTable = $schema.Tables | Where-Object { $_.Name -eq 'projects' }
        $projectsTable.RelationType | Should -Be "OneToMany"
        $fkColumn = $projectsTable.Columns | Where-Object { $_.IsForeignKey }
        $fkColumn | Should -Not -BeNullOrEmpty
        $fkColumn.ReferencesTable | Should -Be "[REPLACE WITH TABLE NAME]"
    }

    It "Routes to Add-ManyToManyObjectArray for ManyToMany relationships" {
        $json = @(
            [PSCustomObject]@{
                id = 1
                name = "Alice"
                projects = @(
                    [PSCustomObject]@{ project_id = 100; title = "ProjA" }
                )
            },
            [PSCustomObject]@{
                id = 2
                name = "Bob"
                projects = @(
                    [PSCustomObject]@{ project_id = 100; title = "ProjA" }
                )
            }
        )
        $schema = JsonToSchemaFromObject -JsonData $json

        $projectsTable = $schema.Tables | Where-Object { $_.Name -eq 'projects' }
        $projectsTable.RelationType | Should -Be "ManyToMany"
        $junctionTable = $schema.JunctionTables | Where-Object { $_.TableName -eq '[REPLACE WITH TABLE NAME]_projects' }
        $junctionTable | Should -Not -BeNullOrEmpty
    }
}

Describe "Get-RelationTypeById" {
    It "Returns OneToMany when no IDs are shared" {
        InModuleScope 'NSTS' {
            $allRecords = @(
                [PSCustomObject]@{ items = @([PSCustomObject]@{ id = 1 }, [PSCustomObject]@{ id = 2 }) }
                [PSCustomObject]@{ items = @([PSCustomObject]@{ id = 3 }) }
            )
            $result = Get-RelationTypeById -PropertyName 'items' -AllRecords $allRecords -PkField 'id'
            $result.Type | Should -Be "OneToMany"
            $result.Reason | Should -Be "Has ID field, but no IDs are shared in sample"
        }
    }

    It "Returns ManyToMany when IDs are shared across parents" {
        InModuleScope 'NSTS' {
            $allRecords = @(
                [PSCustomObject]@{ items = @([PSCustomObject]@{ id = 1 }, [PSCustomObject]@{ id = 2 }) }
                [PSCustomObject]@{ items = @([PSCustomObject]@{ id = 1 }) }  # Shared id=1
            )
            $result = Get-RelationTypeById -PropertyName 'items' -AllRecords $allRecords -PkField 'id'
            $result.Type | Should -Be "ManyToMany"
            $result.Reason | Should -Be "Found 1 shared ID(s) across multiple parents"
        }
    }

    It "Skips null IDs" {
        InModuleScope 'NSTS' {
            $allRecords = @(
                [PSCustomObject]@{ items = @([PSCustomObject]@{ id = $null }, [PSCustomObject]@{ id = 1 }) }
                [PSCustomObject]@{ items = @([PSCustomObject]@{ id = 2 }) }
            )
            $result = Get-RelationTypeById -PropertyName 'items' -AllRecords $allRecords -PkField 'id'
            $result.Type | Should -Be "OneToMany"
        }
    }

    It "Handles empty arrays" {
        InModuleScope 'NSTS' {
            $allRecords = @(
                [PSCustomObject]@{ items = @() }
                [PSCustomObject]@{ items = @([PSCustomObject]@{ id = 1 }) }
            )
            $result = Get-RelationTypeById -PropertyName 'items' -AllRecords $allRecords -PkField 'id'
            $result.Type | Should -Be "OneToMany"
        }
    }
}

Describe "Get-RelationTypeByComposite" {
    It "Returns OneToMany when no identical composites are found" {
        InModuleScope 'NSTS' {
            $allRecords = @(
                [PSCustomObject]@{ items = @([PSCustomObject]@{ name = "A"; value = 1 }, [PSCustomObject]@{ name = "B"; value = 2 }) }
                [PSCustomObject]@{ items = @([PSCustomObject]@{ name = "C"; value = 3 }) }
            )
            $properties = @("name", "value")
            $result = Get-RelationTypeByComposite -PropertyName 'items' -Value $allRecords[0].items -AllRecords $allRecords -Properties $properties
            $result.Type | Should -Be "OneToMany"
            $result.Reason | Should -Be "No identical objects found in sample"
        }
    }

    It "Returns ManyToMany when identical composites are shared across parents" {
        InModuleScope 'NSTS' {
            $allRecords = @(
                [PSCustomObject]@{ items = @([PSCustomObject]@{ name = "A"; value = 1 }) }
                [PSCustomObject]@{ items = @([PSCustomObject]@{ name = "A"; value = 1 }) }  # Identical
            )
            $properties = @("name", "value")
            $result = Get-RelationTypeByComposite -PropertyName 'items' -Value $allRecords[0].items -AllRecords $allRecords -Properties $properties
            $result.Type | Should -Be "ManyToMany"
            $result.Reason | Should -Be "Found 1 identical composite object(s) across parents (may be false positive)"
        }
    }

    It "Filters out metadata fields (timestamp, created, etc.)" {
        InModuleScope 'NSTS' {
            $allRecords = @(
                [PSCustomObject]@{ items = @([PSCustomObject]@{ name = "A"; timestamp = "2023" }) }
                [PSCustomObject]@{ items = @([PSCustomObject]@{ name = "A"; timestamp = "2024" }) }
            )
            $properties = @("name", "timestamp")
            $result = Get-RelationTypeByComposite -PropertyName 'items' -Value $allRecords[0].items -AllRecords $allRecords -Properties $properties
            # Since timestamp is filtered, only 'name' is used, and they are identical
            $result.Type | Should -Be "ManyToMany"
        }
    }

    It "Returns OneToMany when no meaningful fields remain after filtering" {
        InModuleScope 'NSTS' {
            $allRecords = @(
                [PSCustomObject]@{ items = @([PSCustomObject]@{ timestamp = "2023" }) }
                [PSCustomObject]@{ items = @([PSCustomObject]@{ timestamp = "2024" }) }
            )
            $properties = @("timestamp")
            $result = Get-RelationTypeByComposite -PropertyName 'items' -Value $allRecords[0].items -AllRecords $allRecords -Properties $properties
            $result.Type | Should -Be "OneToMany"
            $result.Reason | Should -Be "No meaningful fields to compare"
        }
    }

    It "Handles null values in composite keys" {
        InModuleScope 'NSTS' {
            $allRecords = @(
                [PSCustomObject]@{ items = @([PSCustomObject]@{ name = "A"; value = $null }) }
                [PSCustomObject]@{ items = @([PSCustomObject]@{ name = "A"; value = $null }) }
            )
            $properties = @("name", "value")
            $result = Get-RelationTypeByComposite -PropertyName 'items' -Value $allRecords[0].items -AllRecords $allRecords -Properties $properties
            $result.Type | Should -Be "ManyToMany"
        }
    }
}

Describe "Add-OneToManyObjectArray" {
    It "Creates a OneToMany table with correct columns and foreign key" {
        InModuleScope 'NSTS' {
            $propertyName = 'projects'
            $value = @([PSCustomObject]@{ project_id = 100; title = "ProjA" })
            $MainTableName = 'users'
            $PrimaryKeyField = 'id'
            $autoGenerateId = $false
            $firstRecord = [PSCustomObject]@{ id = 1; name = "Alice" }
            $schema = @{ Tables = @(); JunctionTables = @() }

            $result = Add-OneToManyObjectArray $propertyName $value $MainTableName $PrimaryKeyField $autoGenerateId $firstRecord $schema

            $table = $result.Tables | Where-Object { $_.Name -eq 'projects' }
            $table | Should -Not -BeNullOrEmpty
            $table.RelationType | Should -Be "OneToMany"
            $table.PrimaryKey | Should -Be "project_id"

            $columns = $table.Columns
            $columns | Should -HaveCount 3  # project_id, title, FK
            ($columns | Where-Object { $_.Name -eq 'project_id' }).IsPrimaryKey | Should -Be $true
            ($columns | Where-Object { $_.Name -eq 'title' }).Type | Should -Be "VARCHAR(255)"
            $fkColumn = $columns | Where-Object { $_.IsForeignKey }
            $fkColumn.Name | Should -Be "users_id"
            $fkColumn.ReferencesTable | Should -Be "users"
        }
    }

    It "Uses existing ID field as PK if present" {
        InModuleScope 'NSTS' {
            $propertyName = 'items'
            $value = @([PSCustomObject]@{ id = 1; name = "Item1" })
            $MainTableName = 'orders'
            $PrimaryKeyField = 'order_id'
            $autoGenerateId = $false
            $firstRecord = [PSCustomObject]@{ order_id = 100; total = 50.0 }
            $schema = @{ Tables = @(); JunctionTables = @() }

            $result = Add-OneToManyObjectArray $propertyName $value $MainTableName $PrimaryKeyField $autoGenerateId $firstRecord $schema

            $table = $result.Tables | Where-Object { $_.Name -eq 'items' }
            $table.PrimaryKey | Should -Be "id"
        }
    }

    It "Generates PK if no ID field" {
        InModuleScope 'NSTS' {
            $propertyName = 'tags'
            $value = @([PSCustomObject]@{ name = "Tag1" })
            $MainTableName = 'posts'
            $PrimaryKeyField = 'post_id'
            $autoGenerateId = $false
            $firstRecord = [PSCustomObject]@{ post_id = 1; content = "Hello" }
            $schema = @{ Tables = @(); JunctionTables = @() }

            $result = Add-OneToManyObjectArray $propertyName $value $MainTableName $PrimaryKeyField $autoGenerateId $firstRecord $schema

            $table = $result.Tables | Where-Object { $_.Name -eq 'tags' }
            $table.PrimaryKey | Should -Be "tags_id"
        }
    }
}

Describe "Add-ManyToManyObjectArray" {
    It "Creates a ManyToMany table and junction table" {
        InModuleScope 'NSTS' {
            $propertyName = 'projects'
            $value = @([PSCustomObject]@{ project_id = 100; title = "ProjA" })
            $MainTableName = 'users'
            $PrimaryKeyField = 'id'
            $autoGenerateId = $false
            $firstRecord = [PSCustomObject]@{ id = 1; name = "Alice" }
            $schema = @{ Tables = @(); JunctionTables = @() }

            $result = Add-ManyToManyObjectArray $propertyName $value $MainTableName $PrimaryKeyField $autoGenerateId $firstRecord $schema

            $table = $result.Tables | Where-Object { $_.Name -eq 'projects' }
            $table | Should -Not -BeNullOrEmpty
            $table.RelationType | Should -Be "ManyToMany"
            $table.PrimaryKey | Should -Be "project_id"

            $junction = $result.JunctionTables | Where-Object { $_.TableName -eq 'users_projects' }
            $junction | Should -Not -BeNullOrEmpty
            $junction.Table1 | Should -Be "users"
            $junction.Table2 | Should -Be "projects"
        }
    }

    It "Uses first field as PK if no ID" {
        InModuleScope 'NSTS' {
            $propertyName = 'categories'
            $value = @([PSCustomObject]@{ name = "Cat1"; desc = "Desc" })
            $MainTableName = 'products'
            $PrimaryKeyField = 'product_id'
            $autoGenerateId = $false
            $firstRecord = [PSCustomObject]@{ product_id = 1; price = 10.0 }
            $schema = @{ Tables = @(); JunctionTables = @() }

            $result = Add-ManyToManyObjectArray $propertyName $value $MainTableName $PrimaryKeyField $autoGenerateId $firstRecord $schema

            $table = $result.Tables | Where-Object { $_.Name -eq 'categories' }
            $table.PrimaryKey | Should -Be "name"
        }
    }
}

Describe "Add-SingleObject" {
    It "Creates a table for a single nested object with FK" {
        InModuleScope 'NSTS' {
            $propertyName = 'address'
            $value = [PSCustomObject]@{ street = "123 Main"; city = "NYC" }
            $baseTable = @{ Name = 'users'; PrimaryKey = 'id' }
            $schema = @{ Tables = @(); JunctionTables = @() }

            $result = Add-SingleObject $propertyName $value $baseTable $schema

            $newBaseTable = $result[0]
            $newSchema = $result[1]

            $table = $newSchema.Tables | Where-Object { $_.Name -eq 'address' }
            $table | Should -Not -BeNullOrEmpty
            $table.RelationType | Should -Be "OneToMany"
            $table.PrimaryKey | Should -Be "address_pk"

            $fkColumn = $table.Columns | Where-Object { $_.IsForeignKey }
            $fkColumn.ReferencesTable | Should -Be "users"
        }
    }

    It "Uses existing ID field as PK" {
        InModuleScope 'NSTS' {
            $propertyName = 'profile'
            $value = [PSCustomObject]@{ id = 5; bio = "Bio text" }
            $baseTable = @{ Name = 'users'; PrimaryKey = 'user_id' }
            $schema = @{ Tables = @(); JunctionTables = @() }

            $result = Add-SingleObject $propertyName $value $baseTable $schema

            $table = $result[1].Tables | Where-Object { $_.Name -eq 'profile' }
            $table.PrimaryKey | Should -Be "id"
        }
    }
}

Describe "Get-FieldType" {
    It "Returns SimpleValue for primitives and null" {
        InModuleScope 'NSTS' {
            Get-FieldType $null | Should -Be "SimpleValue"
            Get-FieldType "string" | Should -Be "SimpleValue"
            Get-FieldType 123 | Should -Be "SimpleValue"
        }
    }

    It "Returns SimpleArray for arrays of primitives" {
        InModuleScope 'NSTS' {
            Get-FieldType @("a", "b") | Should -Be "SimpleArray"
            Get-FieldType @() | Should -Be "SimpleArray"
        }
    }

    It "Returns ObjectArray for arrays of objects" {
        InModuleScope 'NSTS' {
            Get-FieldType @([PSCustomObject]@{ id = 1 }) | Should -Be "ObjectArray"
        }
    }

    It "Returns SingleObject for objects" {
        InModuleScope 'NSTS' {
            Get-FieldType ([PSCustomObject]@{ name = "test" }) | Should -Be "SingleObject"
        }
    }
}

Describe "Get-SqlType" {
    It "Maps .NET types to SQL types" {
        InModuleScope 'NSTS' {
            Get-SqlType $null | Should -Be "VARCHAR(255)"
            Get-SqlType "short string" | Should -Be "VARCHAR(255)"
            Get-SqlType ("a" * 300) | Should -Be "TEXT"
            Get-SqlType 123 | Should -Be "INT"
            Get-SqlType 123.45 | Should -Be "FLOAT"
            Get-SqlType $true | Should -Be "BOOLEAN"
            Get-SqlType (Get-Date) | Should -Be "DATETIME"
        }
    }

    It "Defaults to VARCHAR(255) for unknown types" {
        InModuleScope 'NSTS' {
            Get-SqlType ([System.Guid]::NewGuid()) | Should -Be "VARCHAR(255)"
        }
    }
}

Describe "Get-JsonSchema" {
    It "Integrates all functions to produce a complete schema" {
        $json = @(
            [PSCustomObject]@{
                id = 1
                name = "Alice"
                age = 30
                tags = @("Admin")
                projects = @([PSCustomObject]@{ project_id = 100; title = "ProjA" })
                address = [PSCustomObject]@{ street = "123 Main"; city = "NYC" }
            }
        )
        $schema = JsonToSchemaFromObject -JsonData $json

        $schema.Tables | Should -HaveCount 4  # users, tags, projects, address
        $schema.JunctionTables | Should -HaveCount 1  # users_tags

        $usersTable = $schema.Tables | Where-Object { $_.Name -eq '[REPLACE WITH TABLE NAME]' }
        $usersTable.PrimaryKey | Should -Be "id"
        $usersTable.Columns | Where-Object { $_.Name -eq 'name' } | Should -Not -BeNullOrEmpty

        $tagsTable = $schema.Tables | Where-Object { $_.Name -eq 'tags' }
        $tagsTable.RelationType | Should -Be "ManyToMany"

        $projectsTable = $schema.Tables | Where-Object { $_.Name -eq 'projects' }
        $projectsTable.RelationType | Should -Be "OneToMany"

        $addressTable = $schema.Tables | Where-Object { $_.Name -eq 'address' }
        $addressTable.RelationType | Should -Be "OneToMany"
    }
}


