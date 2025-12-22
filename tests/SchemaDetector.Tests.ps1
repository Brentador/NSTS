BeforeAll {
    . "$PSScriptRoot\..\src\Private\Logger.ps1"
    . "$PSScriptRoot\..\src\Private\SchemaDetector.ps1"

    Mock Write-Log { }
}



Describe "Get-PrimaryKeyField" {
    BeforeEach {
        $propertiesWithId = @('id', 'name')
        $propertiesNoId = @('name', 'age')
        $propertiesWithUnderscore = @('test_id', 'name')
        $propertiesWithCamelCase = @('userId', 'name')
        $propertiesWithUpperCase = @('userID', 'name')
        $propertiesWithConst = @('itemconst', 'name')
        $propertiesWithPk = @('pk', 'name')
    }
     It "Detects 'id' as the primary key field" {
        $result = Get-PrimaryKeyField $propertiesWithId
        $result.Field | Should -Be 'id'
        $result.AutoGenerate | Should -Be $false
    }

    It "Auto-generates 'id' when no explicit key is present" {
        $result = Get-PrimaryKeyField $propertiesNoId
        $result.Field | Should -Be 'id'
        $result.AutoGenerate | Should -Be $true
    }

    It "Detects '_id' suffix as the primary key" {
        $result = Get-PrimaryKeyField $propertiesWithUnderscore
        $result.Field | Should -Be 'test_id'
        $result.AutoGenerate | Should -Be $false
    }
    It "Detects 'Id' camelCase as the primary key" {
        $result = Get-PrimaryKeyField $propertiesWithCamelCase
        $result.Field | Should -Be 'userId'
        $result.AutoGenerate | Should -Be $false
    }

    It "Detects 'ID' uppercase as the primary key" {
        $result = Get-PrimaryKeyField $propertiesWithUpperCase
        $result.Field | Should -Be 'userID'
        $result.AutoGenerate | Should -Be $false
    }

    It "Detects 'const' suffix as the primary key" {
        $result = Get-PrimaryKeyField $propertiesWithConst
        $result.Field | Should -Be 'itemconst'
        $result.AutoGenerate | Should -Be $false
    }

    It "Detects 'pk' as the primary key" {
        $result = Get-PrimaryKeyField $propertiesWithPk
        $result.Field | Should -Be 'pk'
        $result.AutoGenerate | Should -Be $false
    }
}

Describe "Get-MainTableName" {
    BeforeEach {
        $pkUserId = 'userId'
        $pkUId = 'uId'
        $pkUnknown = 'unknown'
    }

    It "Generates table name from 'userId'" {
        $result = Get-MainTableName $pkUserId
        $result | Should -Be "users"
    }

    It "Handles single character base names 'uId'" {
        $result = Get-MainTableName $pkUId
        $result | Should -Be "u_records"
    }

    It "Returns placeholder for unknown primary key field" {
        $result = Get-MainTableName $pkUnknown
        $result | Should -Be "[REPLACE WITH TABLE NAME]"
    }
}

Describe "Get-SimpleValue" {
    BeforeEach {
        $pkField = 'id'
        $nameField = 'name'
        $autoGenFalse = $false
        $autoGenTrue = $true
        $intValue = 1
        $stringValue = 'Alice'
    }

    It "Sets IsPrimaryKey true for matching PK field when not auto-generating" {
        Mock Get-SqlType { "INT" }
        $result = Get-SimpleValue $pkField $intValue $pkField $autoGenFalse
        $result.Name | Should -Be $pkField
        $result.Type | Should -Be 'INT'
        $result.IsPrimaryKey | Should -Be $true
    }

    It "Sets IsPrimaryKey false for PK field when auto-generating" {
        Mock Get-SqlType { "INT" }
        $result = Get-SimpleValue $pkField $intValue $pkField $autoGenTrue
        $result.IsPrimaryKey | Should -Be $false
    }

    It "Sets IsPrimaryKey false for non-PK fields" {
        Mock Get-SqlType { "VARCHAR(255)" }
        $result = Get-SimpleValue $nameField $stringValue $pkField $autoGenFalse
        $result.IsPrimaryKey | Should -Be $false
        $result.Type | Should -Be 'VARCHAR(255)'
    }
}

Describe "Add-SimpleArray" {
    BeforeEach {
        $emptySchema = @{ Tables = @(); JunctionTables = @() }
        $firstRecordWithId = [PSCustomObject]@{ id = 1; name = "Alice" }
        $firstRecordNoId = [PSCustomObject]@{ name = "Alice" }
        $tagsArray = @("Admin", "Tester")
        $singleTag = @("Admin")
        $propertyName = 'tags'
        $mainTable = 'users'
        $pkField = 'id'
        $autoGenFalse = $false
        $autoGenTrue = $true
    }

    It "Creates a related table for a simple array" {
        Mock Get-SqlType { param($value) if ($value -is [int]) { "INT" } else { "VARCHAR(255)" } }
        $result = Add-SimpleArray $propertyName $tagsArray $mainTable $pkField $autoGenFalse $firstRecordWithId $emptySchema

        $relatedTable = $result.Tables | Where-Object { $_.Name -eq $propertyName }
        $relatedTable | Should -Not -BeNullOrEmpty
        $relatedTable.RelationType | Should -Be "ManyToMany"
        $relatedTable.PrimaryKey | Should -Be "tags_id"
    }

    It "Creates a junction table for the parent-child relationship" {
        Mock Get-SqlType { param($value) if ($value -is [int]) { "INT" } else { "VARCHAR(255)" } }
        $result = Add-SimpleArray $propertyName $tagsArray $mainTable $pkField $autoGenFalse $firstRecordWithId $emptySchema

        $junctionTable = $result.JunctionTables | Where-Object { $_.TableName -eq 'users_tags' }
        $junctionTable | Should -Not -BeNullOrEmpty
        $junctionTable.Table1 | Should -Be $mainTable
        $junctionTable.Table1FK | Should -Be $pkField
        $junctionTable.Table2 | Should -Be $propertyName
        $junctionTable.Table2FK | Should -Be "tags_id"
    }

    It "Correct column types in the related table" {
        Mock Get-SqlType { param($value) if ($value -is [int]) { "INT" } else { "VARCHAR(255)" } }
        $result = Add-SimpleArray $propertyName $tagsArray $mainTable $pkField $autoGenFalse $firstRecordWithId $emptySchema

        $relatedTable = $result.Tables | Where-Object { $_.Name -eq $propertyName }
        $pkColumn = $relatedTable.Columns | Where-Object { $_.Name -eq 'tags_id' }
        $pkColumn.Type | Should -Be "INT"
        $pkColumn.IsPrimaryKey | Should -Be $true

        $valueColumn = $relatedTable.Columns | Where-Object { $_.Name -eq 'tags_value' }
        $valueColumn.Type | Should -Be "VARCHAR(255)"
        $valueColumn.IsPrimaryKey | Should -Be $false
    }

    It "Correct foreign key type in the junction table (INT if autoGenerateId else Get-SqlType of parent PK)" {
        Mock Get-SqlType { param($value) if ($value -is [int]) { "INT" } else { "VARCHAR(255)" } }
        $result1 = Add-SimpleArray $propertyName $singleTag $mainTable $pkField $autoGenFalse $firstRecordWithId $emptySchema
        ($result1.JunctionTables[0].Columns | Where-Object { $_.Name -eq $pkField }).Type | Should -Be "INT"

        $result2 = Add-SimpleArray $propertyName $singleTag $mainTable $pkField $autoGenTrue $firstRecordNoId $emptySchema
        ($result2.JunctionTables[0].Columns | Where-Object { $_.Name -eq $pkField }).Type | Should -Be "INT"
    }
}

Describe "Add-ObjectArray" {
    BeforeEach {
        $emptySchema = @{ Tables = @(); JunctionTables = @() }
        $mainTablePlaceholder = '[REPLACE WITH TABLE NAME]'
        $pkField = 'id'
        $autoGenFalse = $false
        $propertyName = 'projects'
        $oneToManyRecords = @([PSCustomObject]@{ id = 1; name = "Alice"; projects = @([PSCustomObject]@{ project_id = 100; title = "ProjA" }) })
        $manyToManyRecords = @(
            [PSCustomObject]@{ id = 1; name = "Alice"; projects = @([PSCustomObject]@{ project_id = 100; title = "ProjA" }) },
            [PSCustomObject]@{ id = 2; name = "Bob"; projects = @([PSCustomObject]@{ project_id = 100; title = "ProjA" }) }
        )
    }

    It "Routes to Add-OneToManyObjectArray for OneToMany relationships" {
        Mock Get-RelationTypeById { @{ Type = "OneToMany"; Reason = "mocked" } }
        $firstRecord = $oneToManyRecords[0]
        $result = Add-ObjectArray $propertyName $firstRecord.projects $mainTablePlaceholder $pkField $autoGenFalse $firstRecord $emptySchema $oneToManyRecords $null

        $projectsTable = $result.Tables | Where-Object { $_.Name -eq $propertyName }
        $projectsTable.RelationType | Should -Be "OneToMany"
        $fkColumn = $projectsTable.Columns | Where-Object { $_.IsForeignKey }
        $fkColumn | Should -Not -BeNullOrEmpty
        $fkColumn.ReferencesTable | Should -Be $mainTablePlaceholder
    }

    It "Routes to Add-ManyToManyObjectArray for ManyToMany relationships" {
        Mock Get-RelationTypeById { @{ Type = "ManyToMany"; Reason = "mocked" } }
        $firstRecord = $manyToManyRecords[0]
        $result = Add-ObjectArray $propertyName $firstRecord.projects $mainTablePlaceholder $pkField $autoGenFalse $firstRecord $emptySchema $manyToManyRecords $null

        $projectsTable = $result.Tables | Where-Object { $_.Name -eq $propertyName }
        $projectsTable.RelationType | Should -Be "ManyToMany"
        $junctionTable = $result.JunctionTables | Where-Object { $_.TableName -eq '[REPLACE WITH TABLE NAME]_projects' }
        $junctionTable | Should -Not -BeNullOrEmpty
    }
}

Describe "Get-RelationTypeById" {
    BeforeEach {
        $propertyName = 'items'
        $pkField = 'id'
        $oneToManyRecords = @(
            [PSCustomObject]@{ items = @([PSCustomObject]@{ id = 1 }, [PSCustomObject]@{ id = 2 }) }
            [PSCustomObject]@{ items = @([PSCustomObject]@{ id = 3 }) }
        )
        $manyToManyRecords = @(
            [PSCustomObject]@{ items = @([PSCustomObject]@{ id = 1 }, [PSCustomObject]@{ id = 2 }) }
            [PSCustomObject]@{ items = @([PSCustomObject]@{ id = 1 }) }  # Shared id=1
        )
        $nullIdRecords = @(
            [PSCustomObject]@{ items = @([PSCustomObject]@{ id = $null }, [PSCustomObject]@{ id = 1 }) }
            [PSCustomObject]@{ items = @([PSCustomObject]@{ id = 2 }) }
        )
        $emptyArrayRecords = @(
            [PSCustomObject]@{ items = @() }
            [PSCustomObject]@{ items = @([PSCustomObject]@{ id = 1 }) }
        )
    }

    It "Returns OneToMany when no IDs are shared" {
        $result = Get-RelationTypeById -PropertyName $propertyName -AllRecords $oneToManyRecords -PkField $pkField
        $result.Type | Should -Be "OneToMany"
        $result.Reason | Should -Be "Has ID field, but no IDs are shared in sample"
    }

    It "Returns ManyToMany when IDs are shared across parents" {
        $result = Get-RelationTypeById -PropertyName $propertyName -AllRecords $manyToManyRecords -PkField $pkField
        $result.Type | Should -Be "ManyToMany"
        $result.Reason | Should -Be "Found 1 shared ID(s) across multiple parents"
    }

    It "Skips null IDs" {
        $result = Get-RelationTypeById -PropertyName $propertyName -AllRecords $nullIdRecords -PkField $pkField
        $result.Type | Should -Be "OneToMany"
    }

    It "Handles empty arrays" {
        $result = Get-RelationTypeById -PropertyName $propertyName -AllRecords $emptyArrayRecords -PkField $pkField
        $result.Type | Should -Be "OneToMany"
    }
}

Describe "Get-RelationTypeByComposite" {
    BeforeEach {
        $propertyName = 'items'
        $properties = @("name", "value")
        $oneToManyRecords = @(
            [PSCustomObject]@{ items = @([PSCustomObject]@{ name = "A"; value = 1 }, [PSCustomObject]@{ name = "B"; value = 2 }) }
            [PSCustomObject]@{ items = @([PSCustomObject]@{ name = "C"; value = 3 }) }
        )
        $manyToManyRecords = @(
            [PSCustomObject]@{ items = @([PSCustomObject]@{ name = "A"; value = 1 }) }
            [PSCustomObject]@{ items = @([PSCustomObject]@{ name = "A"; value = 1 }) }  # Identical
        )
        $timestampRecords = @(
            [PSCustomObject]@{ items = @([PSCustomObject]@{ name = "A"; timestamp = "2023" }) }
            [PSCustomObject]@{ items = @([PSCustomObject]@{ name = "A"; timestamp = "2024" }) }
        )
        $onlyTimestampRecords = @(
            [PSCustomObject]@{ items = @([PSCustomObject]@{ timestamp = "2023" }) }
            [PSCustomObject]@{ items = @([PSCustomObject]@{ timestamp = "2024" }) }
        )
        $nullValueRecords = @(
            [PSCustomObject]@{ items = @([PSCustomObject]@{ name = "A"; value = $null }) }
            [PSCustomObject]@{ items = @([PSCustomObject]@{ name = "A"; value = $null }) }
        )
    }

    It "Returns OneToMany when no identical composites are found" {
        $result = Get-RelationTypeByComposite -PropertyName $propertyName -Value $oneToManyRecords[0].items -AllRecords $oneToManyRecords -Properties $properties
        $result.Type | Should -Be "OneToMany"
        $result.Reason | Should -Be "No identical objects found in sample"
    }

    It "Returns ManyToMany when identical composites are shared across parents" {
        $result = Get-RelationTypeByComposite -PropertyName $propertyName -Value $manyToManyRecords[0].items -AllRecords $manyToManyRecords -Properties $properties
        $result.Type | Should -Be "ManyToMany"
        $result.Reason | Should -Be "Found 1 identical composite object(s) across parents (may be false positive)"
    }

    It "Filters out metadata fields (timestamp, created, etc.)" {
        $propertiesWithTimestamp = @("name", "timestamp")
        $result = Get-RelationTypeByComposite -PropertyName $propertyName -Value $timestampRecords[0].items -AllRecords $timestampRecords -Properties $propertiesWithTimestamp
        # Since timestamp is filtered, only 'name' is used, and they are identical
        $result.Type | Should -Be "ManyToMany"
    }

    It "Returns OneToMany when no meaningful fields remain after filtering" {
        $timestampOnlyProperties = @("timestamp")
        $result = Get-RelationTypeByComposite -PropertyName $propertyName -Value $onlyTimestampRecords[0].items -AllRecords $onlyTimestampRecords -Properties $timestampOnlyProperties
        $result.Type | Should -Be "OneToMany"
        $result.Reason | Should -Be "No meaningful fields to compare"
    }

    It "Handles null values in composite keys" {
        $result = Get-RelationTypeByComposite -PropertyName $propertyName -Value $nullValueRecords[0].items -AllRecords $nullValueRecords -Properties $properties
        $result.Type | Should -Be "ManyToMany"
    }
}

Describe "Add-OneToManyObjectArray" {
    BeforeEach {
        $emptySchema = @{ Tables = @(); JunctionTables = @() }
        $propertyName = 'projects'
        $value = @([PSCustomObject]@{ project_id = 100; title = "ProjA" })
        $mainTable = 'users'
        $pkField = 'id'
        $autoGenFalse = $false
        $firstRecord = [PSCustomObject]@{ id = 1; name = "Alice" }
        $itemsProperty = 'items'
        $itemsValue = @([PSCustomObject]@{ id = 1; name = "Item1" })
        $ordersTable = 'orders'
        $orderPk = 'order_id'
        $orderFirstRecord = [PSCustomObject]@{ order_id = 100; total = 50.0 }
        $tagsProperty = 'tags'
        $tagsValue = @([PSCustomObject]@{ name = "Tag1" })
        $postsTable = 'posts'
        $postPk = 'post_id'
        $postFirstRecord = [PSCustomObject]@{ post_id = 1; content = "Hello" }
    }

    It "Creates a OneToMany table with correct columns and foreign key" {
        Mock Get-SqlType { param($value) if ($value -is [int]) { "INT" } else { "VARCHAR(255)" } }
        $result = Add-OneToManyObjectArray $propertyName $value $mainTable $pkField $autoGenFalse $firstRecord $emptySchema

        $table = $result.Tables | Where-Object { $_.Name -eq $propertyName }
        $table | Should -Not -BeNullOrEmpty
        $table.RelationType | Should -Be "OneToMany"
        $table.PrimaryKey | Should -Be "project_id"

        $columns = $table.Columns
        $columns | Should -HaveCount 3  # project_id, title, FK
        ($columns | Where-Object { $_.Name -eq 'project_id' }).IsPrimaryKey | Should -Be $true
        ($columns | Where-Object { $_.Name -eq 'title' }).Type | Should -Be "VARCHAR(255)"
        $fkColumn = $columns | Where-Object { $_.IsForeignKey }
        $fkColumn.Name | Should -Be "users_id"
        $fkColumn.ReferencesTable | Should -Be $mainTable
    }

    It "Uses existing ID field as PK if present" {
        Mock Get-SqlType { param($value) if ($value -is [int]) { "INT" } else { "VARCHAR(255)" } }
        $result = Add-OneToManyObjectArray $itemsProperty $itemsValue $ordersTable $orderPk $autoGenFalse $orderFirstRecord $emptySchema

        $table = $result.Tables | Where-Object { $_.Name -eq $itemsProperty }
        $table.PrimaryKey | Should -Be "id"
    }

    It "Generates PK if no ID field" {
        Mock Get-SqlType { param($value) if ($value -is [int]) { "INT" } else { "VARCHAR(255)" } }
        $result = Add-OneToManyObjectArray $tagsProperty $tagsValue $postsTable $postPk $autoGenFalse $postFirstRecord $emptySchema

        $table = $result.Tables | Where-Object { $_.Name -eq $tagsProperty }
        $table.PrimaryKey | Should -Be "tags_id"
    }
}

Describe "Add-ManyToManyObjectArray" {
    BeforeEach {
        $emptySchema = @{ Tables = @(); JunctionTables = @() }
        $propertyName = 'projects'
        $value = @([PSCustomObject]@{ project_id = 100; title = "ProjA" })
        $mainTable = 'users'
        $pkField = 'id'
        $autoGenFalse = $false
        $firstRecord = [PSCustomObject]@{ id = 1; name = "Alice" }
        $categoriesProperty = 'categories'
        $categoriesValue = @([PSCustomObject]@{ name = "Cat1"; desc = "Desc" })
        $productsTable = 'products'
        $productPk = 'product_id'
        $productFirstRecord = [PSCustomObject]@{ product_id = 1; price = 10.0 }
    }

    It "Creates a ManyToMany table and junction table" {
        Mock Get-SqlType { param($value) if ($value -is [int]) { "INT" } else { "VARCHAR(255)" } }
        $result = Add-ManyToManyObjectArray $propertyName $value $mainTable $pkField $autoGenFalse $firstRecord $emptySchema

        $table = $result.Tables | Where-Object { $_.Name -eq $propertyName }
        $table | Should -Not -BeNullOrEmpty
        $table.RelationType | Should -Be "ManyToMany"
        $table.PrimaryKey | Should -Be "project_id"

        $junction = $result.JunctionTables | Where-Object { $_.TableName -eq 'users_projects' }
        $junction | Should -Not -BeNullOrEmpty
        $junction.Table1 | Should -Be $mainTable
        $junction.Table2 | Should -Be $propertyName
    }

    It "Uses first field as PK if no ID" {
        Mock Get-SqlType { param($value) if ($value -is [int]) { "INT" } else { "VARCHAR(255)" } }
        $result = Add-ManyToManyObjectArray $categoriesProperty $categoriesValue $productsTable $productPk $autoGenFalse $productFirstRecord $emptySchema

        $table = $result.Tables | Where-Object { $_.Name -eq $categoriesProperty }
        $table.PrimaryKey | Should -Be "name"
    }
}

Describe "Add-SingleObject" {
    BeforeEach {
        $emptySchema = @{ Tables = @(); JunctionTables = @() }
        $addressProperty = 'address'
        $addressValue = [PSCustomObject]@{ street = "123 Main"; city = "NYC" }
        $baseTable = @{ Name = 'users'; PrimaryKey = 'id' }
        $profileProperty = 'profile'
        $profileValue = [PSCustomObject]@{ id = 5; bio = "Bio text" }
        $baseTableWithUserId = @{ Name = 'users'; PrimaryKey = 'user_id' }
    }

    It "Creates a table for a single nested object with FK" {
        Mock Get-SqlType { param($value) if ($value -is [int]) { "INT" } else { "VARCHAR(255)" } }
        $result = Add-SingleObject $addressProperty $addressValue $baseTable $emptySchema

        $newBaseTable = $result[0]
        $newSchema = $result[1]

        $table = $newSchema.Tables | Where-Object { $_.Name -eq $addressProperty }
        $table | Should -Not -BeNullOrEmpty
        $table.RelationType | Should -Be "OneToMany"
        $table.PrimaryKey | Should -Be "address_pk"

        $fkColumn = $table.Columns | Where-Object { $_.IsForeignKey }
        $fkColumn.ReferencesTable | Should -Be $baseTable.Name
    }

    It "Uses existing ID field as PK" {
        Mock Get-SqlType { param($value) if ($value -is [int]) { "INT" } else { "VARCHAR(255)" } }
        $result = Add-SingleObject $profileProperty $profileValue $baseTableWithUserId $emptySchema

        $table = $result[1].Tables | Where-Object { $_.Name -eq $profileProperty }
        $table.PrimaryKey | Should -Be "id"
    }
}

Describe "Get-SqlType" {
    It "Maps .NET types to SQL types" {
        Get-SqlType $null | Should -Be "VARCHAR(255)"
        Get-SqlType "short string" | Should -Be "VARCHAR(255)"
        Get-SqlType ("a" * 300) | Should -Be "TEXT"
        Get-SqlType 123 | Should -Be "INT"
        Get-SqlType 123.45 | Should -Be "FLOAT"
        Get-SqlType $true | Should -Be "BOOLEAN"
        Get-SqlType (Get-Date) | Should -Be "DATETIME"
    }

    It "Defaults to VARCHAR(255) for unknown types" {
        Get-SqlType ([System.Guid]::NewGuid()) | Should -Be "VARCHAR(255)"
    }
}




