# NSTS - NoSQL To SQL

A PowerShell tool that automatically converts JSON files into MySQL database schemas with intelligent relationship detection.

## What Does This Tool Do?

NSTS analyzes your JSON data and automatically:
- Detects table structures and column types
- Identifies primary keys and relationships
- Determines one-to-many vs many-to-many relationships
- Generates MySQL CREATE TABLE statements
- Optionally executes the SQL directly on your database

**Example:** Turn a JSON file containing users with nested orders, tags, and addresses into a complete relational database schema with proper tables, foreign keys, and junction tables.

---

## Installation

### 1. Clone or Download This Repository
```powershell
git clone https://github.com/Brentador/NSTS.git
cd NSTS
cd src
```

### 2. Import the Module
```powershell
Import-Module .\NSTS.psm1
```

> **Note:** You only need to import the module once per PowerShell session.

---

## Quick Start

### Three Main Functions

| Function | Description |
|----------|-------------|
| `JsonToSchema` | Convert JSON file to schema, validate, and save |
| `SchemaToSql` | Load schema and generate SQL statements |
| `DryRun` | Preview the entire conversion without saving |

### Basic Workflow
```powershell
# Step 1: Convert JSON to validated schema
JsonToSchema
# Select your JSON file in the file dialog
# Review and edit the detected schema
# Save the schema as a .json file

# Step 2: Convert schema to SQL
SchemaToSql
# Select your schema file
# Review the generated SQL
# Save as .sql file
# Optionally execute on MySQL database
```

### Quick Test (Dry Run)
```powershell
DryRun
# See what SQL would be generated without saving anything
```

---

## How It Works

### Step 1: JSON Analysis
The tool reads your JSON file and examines the first record to understand:

| JSON Structure | Becomes |
|---------------|---------|
| **Simple fields** (strings, numbers, booleans) | Table columns |
| **Arrays of values** `["tag1", "tag2"]` | Separate table with many-to-many relationship |
| **Arrays of objects** `[{id: 1, name: "x"}]` | Related table (one-to-many or many-to-many) |
| **Nested objects** `{address: {street: "..."}}` | Related table with foreign key |

### Step 2: Schema Detection
The tool automatically:
- **Finds or generates primary keys** - Looks for fields like `id`, `userId`, `user_id`, `_id`, etc.
- **Derives table names** - `userId` → `users` table
- **Maps JSON types to SQL types** - String → VARCHAR, Number → INT, etc.
- **Detects relationship types** - Analyzes if object arrays share data across records

### Relationship Detection Logic:
- **One-to-Many**: Child objects have IDs that are unique across all parent records (no sharing). Example: A user has multiple unique orders.
- **Many-to-Many**: Child objects have IDs that appear in multiple parent records (shared). Example: Products belong to multiple categories.

### Step 3: Interactive Validation
You'll see the detected schema with **color-coded** tables and columns:
```
==================== DETECTED SCHEMA ====================

[TABLES]
  [0] Table: users (PK: userId)
      Columns:
        - userId (INT) <- PRIMARY KEY
        - name (VARCHAR(255))
        - email (VARCHAR(255))

  [1] Table: tags (PK: tags_id)
      Columns:
        - tags_id (INT) <- PRIMARY KEY
        - tags_value (VARCHAR(255))
      Relation: ManyToMany

[RELATIONSHIPS (Junction Tables)]
  users_tags
    Links: userId -> tags_id
```

**You can:**
- **Accept** the schema as-is
- **Edit** table names, column names, data types, or primary keys
- **Add** new columns
- **Remove** columns

### Step 4: SQL Generation
Generates proper MySQL CREATE TABLE statements with:
- Primary keys
- Foreign key constraints
- Junction tables for many-to-many relationships
- Properly typed columns

### Step 5: Optional Execution
- Save the SQL to a file for later use
- Execute immediately on your MySQL database

---

## Example Usage

### Input JSON

**Recommended Structure** (most reliable):
```json
[
  {
    "userId": 1,
    "name": "John Doe",
    "email": "john@example.com",
    "tags": ["premium", "verified"],
    "address": {
      "street": "123 Main St",
      "city": "New York"
    }
  },
  {
    "userId": 2,
    "name": "Jane Smith",
    "email": "jane@example.com",
    "tags": ["verified"]
  }
]
```

> **Best Practice:** Always use an array of objects, even for a single record. Include consistent ID fields like `userId`, `orderId`, etc.

### Running the Conversion
```powershell
# Convert JSON to schema
JsonToSchema
```

**What happens:**
1. File dialog opens → Select `users.json`
2. Schema is detected and displayed
3. You're prompted: **Accept (A) / Edit (E) / Quit (Q)**
4. If you choose Edit, you can modify the schema interactively
5. Save the schema as `users_schema.json`
```powershell
# Convert schema to SQL
SchemaToSql
```

**What happens:**
1. File dialog opens → Select `users_schema.json`
2. SQL statements are generated and displayed
3. Save as `users.sql`
4. Optionally execute on MySQL

### Generated SQL Output
```sql
CREATE TABLE users (
    userId INT PRIMARY KEY,
    name VARCHAR(255),
    email VARCHAR(255)
);


CREATE TABLE tags (
    tags_id INT PRIMARY KEY,
    tags_value VARCHAR(255)
);


CREATE TABLE address (
    address_pk INT PRIMARY KEY,
    street VARCHAR(255),
    city VARCHAR(255),
    userId INT,
    FOREIGN KEY (userId) REFERENCES users(userId)
);


CREATE TABLE users_tags (
    userId INT,
    tags_id INT,
    PRIMARY KEY (userId, tags_id),
    FOREIGN KEY (userId) REFERENCES users(userId),
    FOREIGN KEY (tags_id) REFERENCES tags(tags_id)
);
```

---

## Advanced Features

### Overriding Relationship Detection

If the tool misdetects a relationship type, you can manually override it:
```powershell

# Use the overrides
JsonToSchema -RelationshipOverrides @{ 'address' = 'ManyToMany'}
JsonToSchema -RelationshipOverrides @{ 'tags' = 'OneToMany'}    
```

**When to use overrides:**
- The tool incorrectly identifies a one-to-many as many-to-many
- You know the business logic better than the detection algorithm
- Your sample data doesn't represent the full relationship pattern

### Interactive Schema Editing

During the `JsonToSchema` step, you can edit tables:

**Table-Level Actions:**
- `[0]` - Rename the table
- `[1]` - Change the primary key
- `[A]` - Add a new column
- `[R]` - Remove a column
- `[D]` - Done editing

**Column-Level Actions (select column number):**
- Rename the column
- Change the data type
- Automatic foreign key updates

**Example Session:**
```
What do you want to edit?
  [0] Table name: users
  [1] Primary key: userId
  [2] Column: userId (INT) <- PRIMARY KEY
  [3] Column: name (VARCHAR(255))
  [4] Column: email (VARCHAR(255))
  [5] Column: username (VARCHAR(255))
  [A] Add column
  [R] Remove column
  [D] Done editing this table

Your choice: a
Enter new column name: available
Select a valid dataType from the list: 
TINYINT, SMALLINT, MEDIUMINT, INT, INTEGER, BIGINT, DECIMAL, DEC, NUMERIC, FIXED, FLOAT, DOUBLE, DOUBLE PRECISION, REAL, BIT, BOOL, BOOLEAN, DATE, TIME, DATETIME, TIMESTAMP, YEAR
CHAR, VARCHAR, TINYTEXT, TEXT, MEDIUMTEXT, LONGTEXT, BINARY, VARBINARY, TINYBLOB, BLOB, MEDIUMBLOB, LONGBLOB, ENUM, SET
GEOMETRY, POINT, LINESTRING, POLYGON, MULTIPOINT, MULTILINESTRING, MULTIPOLYGON, GEOMETRYCOLLECTION, JSON
Enter data type for available [VARCHAR(255)]: BOOLEAN
```

### Secure MySQL Execution

**Example:**
```powershell
SchemaToSql
# After saving SQL...
Do you want to execute this SQL on a MySQL database now? (Y/N): Y
Enter path to mysql.exe: C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe
Enter MySQL server address: localhost
Enter MySQL database name: my_database
Enter MySQL username: root
Enter MySQL password: ********
```

### Comprehensive Logging

All operations are logged to `.\logs\`:
```
NSTS/
└── logs/
    ├── json-to-schema/
    │   └── json-to-schema_20251228_143022.log
    ├── schema-to-sql/
    │   └── schema-to-sql_20251228_143145.log
    └── json-to-sql-dryrun/
        └── json-to-sql-dryrun_20251228_143300.log
```

**Log Contents:**
- Schema detection steps
- User actions (edits, adds, removes)
- Errors and warnings

---

## Supported Data Types

### Auto-Detected Types (from JSON)

When analyzing JSON, the tool automatically maps types:

| JSON Type | Default MySQL Type |
|-----------|-------------------|
| String (≤255 chars) | `VARCHAR(255)` |
| String (>255 chars) | `TEXT` |
| Integer | `INT` |
| Float/Decimal | `FLOAT` |
| Boolean | `BOOLEAN` |
| Date/Time | `DATETIME` |
| Null/Unknown | `VARCHAR(255)` |

### All Available MySQL Types

When **editing schema** or **adding columns**, you can use any valid MySQL type:

#### Numeric Types
`TINYINT`, `SMALLINT`, `MEDIUMINT`, `INT`, `INTEGER`, `BIGINT`, `DECIMAL`, `DEC`, `NUMERIC`, `FIXED`, `FLOAT`, `DOUBLE`, `DOUBLE PRECISION`, `REAL`, `BIT`, `BOOL`, `BOOLEAN`

#### Date/Time Types
`DATE`, `TIME`, `DATETIME`, `TIMESTAMP`, `YEAR`

#### String Types
`CHAR`, `VARCHAR`, `TINYTEXT`, `TEXT`, `MEDIUMTEXT`, `LONGTEXT`, `BINARY`, `VARBINARY`, `TINYBLOB`, `BLOB`, `MEDIUMBLOB`, `LONGBLOB`, `ENUM`, `SET`

#### Spatial Types
`GEOMETRY`, `POINT`, `LINESTRING`, `POLYGON`, `MULTIPOINT`, `MULTILINESTRING`, `MULTIPOLYGON`, `GEOMETRYCOLLECTION`

#### Other
`JSON`

> **Note:** You can specify size/precision for types like `VARCHAR(100)`, `DECIMAL(10,2)`, `CHAR(5)`, etc.

---

## Troubleshooting

### Common Issues

#### "mysql.exe not found"
**Solution:**
- Ensure MySQL is installed
- Provide the full path to `mysql.exe`
- Common paths:
  - `C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe`
  - `C:\Program Files\MySQL\MySQL Server 5.7\bin\mysql.exe`

#### "No ID field found"
**What this means:** The tool couldn't find a primary key field.

**Solution:**
- The tool will auto-generate an `id` column as the primary key
- You can change this in the schema validation step
- **Best practice:** Name your ID fields consistently (`id`, `userId`, `user_id`, etc.)

#### Relationship type seems wrong
**Example:** Orders are detected as many-to-many when they should be one-to-many.

**Solution:**
```powershell
$overrides = @{
    "orders" = "OneToMany"
}
JsonToSchema -RelationshipOverrides $overrides
```

**Why this happens:**
- Detection is based on your sample data
- If your JSON only has 1-2 records, patterns may not be clear
- Business logic may differ from data patterns
---

## Requirements

- **PowerShell 5.1** or higher
- **Windows** (uses System.Windows.Forms for file dialogs)
- **MySQL** (optional, only needed if executing SQL directly)

---

## File Structure
```
NSTS/
├── README.md
├── src/
│   ├── NSTS.psm1              # Main module (entry point)
│   └── Private/
│       ├── JsonReader.ps1      # JSON file parsing
│       ├── SchemaDetector.ps1  # Schema analysis and detection
│       ├── SchemaValidator.ps1 # Interactive schema editing
│       ├── SQLConverter.ps1    # SQL generation
│       ├── Logger.ps1          # Logging utilities
│       └── DatabaseExecutor.ps1 # MySQL execution
└── logs/                       # Auto-generated logs (created on first run)
    ├── json-to-schema/
    ├── schema-to-sql/
    └── json-to-sql-dryrun/
```

---

## Tips & Best Practices

### 1. Structure Your JSON Properly
**Good:**
```json
[
  {"userId": 1, "name": "John"},
  {"userId": 2, "name": "Jane"}
]
```

**Avoid:**
```json
{"userId": 1, "name": "John"}  // Not an array
```

### 2. Use Consistent ID Fields
**Good:** `userId`, `orderId`, `product_id`  
**Avoid:** `user`, `orderNumber`, `prod`

### 3. Test with Dry Runs
Always run `DryRun` first to preview the output before committing to files.

### 4. Check the Logs
Review `.\logs\` if something doesn't work as expected.

### 5. Validate Before Executing
Always review the generated SQL before executing on a production database.

### 6. Backup Your Database
Before executing SQL on an existing database, create a backup:

---

## Planned

**1. Currently, only MySQL is supported. PostgreSQL/SQL Server support may be added in future versions.**

**2. Currently, the tool focuses on schema generation (CREATE TABLE statements). Optional data generation and INSERT statement output is planned.**

**3. Currently, the script only provides logging to trace past actions and errors. In a future extension, a reporting feature will be added that generates a structured summary of the entire execution, including detected schemas, created tables, relationships, record counts, warnings, and validation issues.**

---

## References

### AI-assisted development
- Inline AI and Copilot for bug detection and syntax validation
- Inline AI and Copilot for code documentation
- Inline AI and Copilot for improving TUI and user experience
- Inline AI and Copilot was used for analysis, validation, code logic and refactoring if i was stuck and not making progress

### Official documentation
- PowerShell Read-Host with AsSecureString for MySQL db connection  
  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/read-host?view=powershell-7.5

### Test data
- IMDb-derived JSON test dataset  
  https://github.com/FEND16/movie-json-data/tree/master

### Design and implementation discussions
- Dry-run feature explanation and sanity check  
  https://chatgpt.com/share/69514d89-3744-800f-916b-461d2ad9ac64
- Database connection handling in PowerShell  
  https://chatgpt.com/share/69514db5-dbd8-800f-b458-7d79941c9635
- One-to-many relationship handling in schema detection  
  https://chatgpt.com/share/69514f3d-c7a0-800f-94c0-999e785a5562
- Write-Host vs Write-Output usage for the TUI  
  https://chatgpt.com/share/69514fd5-4ba0-800f-a4ed-99dddc4e76df
- Project structure refactor and function documentation  
  https://chatgpt.com/share/69515059-3fb0-800f-9f41-5f8e52ea73f3
- Creating tests with Pester  
  https://chatgpt.com/share/695150c3-7548-800f-a347-cc579c7c822c
- SQL execution and helper function review  
  https://chatgpt.com/share/6951510d-4318-800f-a311-bda0526c901e

### Additional AI-assisted reviews
- Converting integration tests to unit tests  
  https://claude.ai/share/2e7c78a0-0600-4438-a662-b304d1cd753f
- JSON structure validation for schema conversion  
  https://claude.ai/share/c71b6384-2950-478d-9c2b-9a14601bd22b

### External resources
- File dialog selection in PowerShell  
  https://claytonerrington.com/blog/file-dialog-with-powershell/
- MySQL 8.0 Reserved Words and Keywords  
  https://dev.mysql.com/doc/refman/8.0/en/keywords.html
- MySQL Identifier Names and Limits  
  https://dev.mysql.com/doc/refman/8.0/en/identifiers.html
- MySQL Data Types  
  https://dev.mysql.com/doc/refman/8.0/en/data-types.html
- MySQL CREATE TABLE Syntax  
  https://dev.mysql.com/doc/refman/8.0/en/create-table.html

  
**Made by [Brentador](https://github.com/Brentador)**

*If this tool saved you time, consider giving it a star on GitHub!*

