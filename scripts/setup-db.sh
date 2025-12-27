#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}Database Table Setup Script${NC}"
echo "=============================="
echo ""

# Check if Cargo.toml exists
if [ ! -f "Cargo.toml" ]; then
    echo -e "${RED}Error: Cargo.toml not found${NC}"
    exit 1
fi

# Extract project name from Cargo.toml (get the package name, not the binary name)
# Look for name = in the [package] section specifically
PROJECT_NAME=$(awk '/^\[package\]/ {in_package=1} in_package && /^name =/ {gsub(/"/, "", $3); print $3; exit} /^\[/ && !/^\[package\]/ {in_package=0}' Cargo.toml)
if [ -z "$PROJECT_NAME" ]; then
    # Fallback: try the simpler method (first name = line, which should be package name)
    PROJECT_NAME=$(awk -F'"' '/^name =/ {print $2; exit}' Cargo.toml)
    if [ -z "$PROJECT_NAME" ]; then
        echo -e "${RED}Error: Could not extract project name from Cargo.toml${NC}"
        exit 1
    fi
fi

# Convert project name to underscore format for table name
PROJECT_NAME_UNDERSCORE=$(echo "$PROJECT_NAME" | tr '-' '_')
TABLE_NAME="${PROJECT_NAME_UNDERSCORE}_table"

echo -e "${BLUE}Project name: ${PROJECT_NAME}${NC}"
echo -e "${BLUE}Table name: ${TABLE_NAME}${NC}"
echo ""

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}Error: docker-compose.yml not found${NC}"
    exit 1
fi

# Extract database connection info from docker-compose.yml
POSTGRES_USER=$(grep -A 10 "postgres:" docker-compose.yml | grep "POSTGRES_USER:" | sed -E 's/.*POSTGRES_USER:\s*(.+)/\1/' | tr -d ' ')
POSTGRES_PASSWORD=$(grep -A 10 "postgres:" docker-compose.yml | grep "POSTGRES_PASSWORD:" | sed -E 's/.*POSTGRES_PASSWORD:\s*(.+)/\1/' | tr -d ' ')
POSTGRES_DB=$(grep -A 10 "postgres:" docker-compose.yml | grep "POSTGRES_DB:" | sed -E 's/.*POSTGRES_DB:\s*(.+)/\1/' | tr -d ' ')
CONTAINER_NAME=$(grep -A 10 "postgres:" docker-compose.yml | grep "container_name:" | sed -E 's/.*container_name:\s*(.+)/\1/' | tr -d ' ')

if [ -z "$POSTGRES_USER" ] || [ -z "$POSTGRES_PASSWORD" ] || [ -z "$POSTGRES_DB" ] || [ -z "$CONTAINER_NAME" ]; then
    echo -e "${RED}Error: Could not extract database connection info from docker-compose.yml${NC}"
    echo "Please make sure docker-compose.yml contains PostgreSQL service configuration"
    exit 1
fi

echo -e "${BLUE}Database: ${POSTGRES_DB}${NC}"
echo -e "${BLUE}User: ${POSTGRES_USER}${NC}"
echo -e "${BLUE}Container: ${CONTAINER_NAME}${NC}"
echo ""

# Check if container is running
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo -e "${YELLOW}Warning: PostgreSQL container '$CONTAINER_NAME' is not running${NC}"
    echo "Please start it with: docker-compose up -d"
    exit 1
fi

# Field collection
FIELDS=()
FIELD_TYPES=()
FIELD_NAMES=()
RUST_TYPES=()

echo -e "${GREEN}Let's define the table fields!${NC}"
echo "The table will automatically include:"
echo "  - id field (SERIAL PRIMARY KEY)"
echo "  - created_on field (TIMESTAMP WITH TIME ZONE, auto-set on creation)"
echo "  - changed_on field (TIMESTAMP WITH TIME ZONE, auto-updated on changes)"
echo ""

ADD_MORE="y"
FIELD_NUM=1

while [ "$ADD_MORE" = "y" ] || [ "$ADD_MORE" = "Y" ]; do
    echo -e "${YELLOW}Field #${FIELD_NUM}${NC}"
    read -p "Enter field name: " FIELD_NAME
    
    # Validate field name (alphanumeric and underscore only)
    if ! [[ "$FIELD_NAME" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        echo -e "${RED}Error: Invalid field name. Use only letters, numbers, and underscores (must start with letter or underscore)${NC}"
        continue
    fi
    
    echo ""
    echo "Available data types:"
    echo "  1) string  - VARCHAR(255) - for text up to 255 characters"
    echo "  2) text    - TEXT - for longer text"
    echo "  3) int     - INTEGER - for whole numbers"
    echo "  4) bigint  - BIGINT - for large whole numbers"
    echo "  5) float   - REAL - for decimal numbers"
    echo "  6) double  - DOUBLE PRECISION - for high precision decimals"
    echo "  7) bool    - BOOLEAN - for true/false values"
    echo "  8) date    - TIMESTAMP WITH TIME ZONE - for date and time"
    echo "  9) json    - JSONB - for JSON data"
    echo ""
    read -p "Enter field type (1-9 or type name): " TYPE_CHOICE
    
    # Map type choice to PostgreSQL type and Rust type
    case "$TYPE_CHOICE" in
        1|string)
            PG_TYPE="VARCHAR(255)"
            RUST_TYPE="String"
            ;;
        2|text)
            PG_TYPE="TEXT"
            RUST_TYPE="String"
            ;;
        3|int)
            PG_TYPE="INTEGER"
            RUST_TYPE="i32"
            ;;
        4|bigint)
            PG_TYPE="BIGINT"
            RUST_TYPE="i64"
            ;;
        5|float)
            PG_TYPE="REAL"
            RUST_TYPE="f32"
            ;;
        6|double)
            PG_TYPE="DOUBLE PRECISION"
            RUST_TYPE="f64"
            ;;
        7|bool)
            PG_TYPE="BOOLEAN"
            RUST_TYPE="bool"
            ;;
        8|date)
            PG_TYPE="TIMESTAMP WITH TIME ZONE"
            RUST_TYPE="chrono::DateTime<chrono::Utc>"
            ;;
        9|json)
            PG_TYPE="JSONB"
            RUST_TYPE="serde_json::Value"
            ;;
        *)
            echo -e "${RED}Error: Invalid type choice${NC}"
            continue
            ;;
    esac
    
    FIELDS+=("$FIELD_NAME $PG_TYPE")
    FIELD_TYPES+=("$PG_TYPE")
    FIELD_NAMES+=("$FIELD_NAME")
    RUST_TYPES+=("$RUST_TYPE")
    
    echo -e "${GREEN}✓ Added field: $FIELD_NAME ($PG_TYPE)${NC}"
    echo ""
    
    read -p "Add another field? (y/n): " ADD_MORE
    FIELD_NUM=$((FIELD_NUM + 1))
done

if [ ${#FIELDS[@]} -eq 0 ]; then
    echo -e "${YELLOW}No fields added. Table will only have 'id' field.${NC}"
fi

echo ""
echo -e "${YELLOW}Table structure:${NC}"
echo "  id SERIAL PRIMARY KEY"
echo "  created_on TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP"
echo "  changed_on TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP"
for field in "${FIELDS[@]}"; do
    echo "  $field"
done
echo ""

read -p "Create this table? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Aborted."
    exit 0
fi

# Build CREATE TABLE SQL
SQL="CREATE TABLE IF NOT EXISTS ${TABLE_NAME} (
    id SERIAL PRIMARY KEY,
    created_on TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    changed_on TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP"

for field in "${FIELDS[@]}"; do
    SQL="${SQL},
    ${field}"
done

SQL="${SQL}
);"

echo ""
echo "Creating table..."
echo "$SQL" | docker exec -i "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Table '${TABLE_NAME}' created successfully!${NC}"
    
    # Create trigger function to automatically update changed_on
    echo "Creating trigger to auto-update changed_on..."
    TRIGGER_SQL="
CREATE OR REPLACE FUNCTION update_changed_on_column()
RETURNS TRIGGER AS \$\$
BEGIN
    NEW.changed_on = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
\$\$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_${TABLE_NAME}_changed_on ON ${TABLE_NAME};
CREATE TRIGGER update_${TABLE_NAME}_changed_on
    BEFORE UPDATE ON ${TABLE_NAME}
    FOR EACH ROW
    EXECUTE FUNCTION update_changed_on_column();
"
    echo "$TRIGGER_SQL" | docker exec -i "$CONTAINER_NAME" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Trigger created successfully!${NC}"
    else
        echo -e "${YELLOW}Warning: Failed to create trigger, but table was created${NC}"
    fi
else
    echo -e "${RED}Error: Failed to create table${NC}"
    exit 1
fi

# Generate Rust code for CRUD operations
echo ""
echo "Generating CRUD operations for main.rs..."

# Convert snake_case to camelCase for Rust field names
to_camel_case() {
    # Convert snake_case to camelCase (first letter lowercase, rest camelCase)
    echo "$1" | sed -r 's/_([a-z])/\U\1/g' | sed 's/^[a-z]/\L&/'
}

# Generate struct name (PascalCase) - ensure first letter is uppercase
# Convert snake_case to PascalCase: actixtest -> Actixtest, my_project -> MyProject
# Use awk to properly handle case conversion
STRUCT_NAME=$(echo "$PROJECT_NAME_UNDERSCORE" | awk '{
    result = ""
    split($0, parts, "_")
    for (i = 1; i <= length(parts); i++) {
        if (length(parts[i]) > 0) {
            first_char = toupper(substr(parts[i], 1, 1))
            rest = substr(parts[i], 2)
            result = result first_char rest
        }
    }
    if (length(result) == 0) {
        # If no underscores, just capitalize first letter
        first_char = toupper(substr($0, 1, 1))
        rest = substr($0, 2)
        result = first_char rest
    }
    print result
}')
STRUCT_NAME="${STRUCT_NAME}Record"
REQUEST_NAME="Create${STRUCT_NAME}Request"

# Create temporary file for generated code
CRUD_FILE=$(mktemp)

# Generate struct definition
cat > "$CRUD_FILE" << EOF
// Generated by setup-db.sh - DO NOT EDIT MANUALLY
// Table: ${TABLE_NAME}

#[derive(Debug, serde::Serialize, serde::Deserialize, sqlx::FromRow)]
pub struct ${STRUCT_NAME} {
    pub id: i32,
    pub created_on: chrono::DateTime<chrono::Utc>,
    pub changed_on: chrono::DateTime<chrono::Utc>,
EOF

for i in "${!FIELD_NAMES[@]}"; do
    FIELD_NAME="${FIELD_NAMES[$i]}"
    # Use snake_case for database fields (not camelCase) to match SQL column names
    RUST_TYPE="${RUST_TYPES[$i]}"
    echo "    pub ${FIELD_NAME}: ${RUST_TYPE}," >> "$CRUD_FILE"
done

cat >> "$CRUD_FILE" << EOF
}

#[derive(serde::Deserialize)]
pub struct ${REQUEST_NAME} {
EOF

for i in "${!FIELD_NAMES[@]}"; do
    FIELD_NAME="${FIELD_NAMES[$i]}"
    # Use snake_case for database fields (not camelCase) to match SQL column names
    RUST_TYPE="${RUST_TYPES[$i]}"
    echo "    pub ${FIELD_NAME}: ${RUST_TYPE}," >> "$CRUD_FILE"
done

cat >> "$CRUD_FILE" << EOF
}

// CRUD operations
async fn create_${PROJECT_NAME_UNDERSCORE}(
    pool: web::Data<PgPool>,
    record: web::Json<${REQUEST_NAME}>,
) -> Result<impl Responder> {
EOF

# Build INSERT query dynamically
# created_on and changed_on are automatically set by the database, so we don't include them in INSERT
if [ ${#FIELD_NAMES[@]} -gt 0 ]; then
    # Build query string using string concatenation
    echo "    let fields: Vec<&str> = vec![" >> "$CRUD_FILE"
    for name in "${FIELD_NAMES[@]}"; do
        echo "        \"${name}\"," >> "$CRUD_FILE"
    done
    echo "    ];" >> "$CRUD_FILE"
    echo "    let fields_str = fields.join(\", \");" >> "$CRUD_FILE"
    echo '    let placeholders: Vec<String> = (1..=fields.len()).map(|i| format!("${}", i)).collect();' >> "$CRUD_FILE"
    echo "    let values_str = placeholders.join(\", \");" >> "$CRUD_FILE"
    echo "    let query = format!(\"INSERT INTO ${TABLE_NAME} ({}) VALUES ({}) RETURNING *\", fields_str, values_str);" >> "$CRUD_FILE"
    echo "" >> "$CRUD_FILE"
    echo "    let result = sqlx::query_as::<_, ${STRUCT_NAME}>(&query)" >> "$CRUD_FILE"
    for i in "${!FIELD_NAMES[@]}"; do
        FIELD_NAME="${FIELD_NAMES[$i]}"
        echo "        .bind(&record.${FIELD_NAME})" >> "$CRUD_FILE"
    done
    echo "        .fetch_one(pool.get_ref())" >> "$CRUD_FILE"
    echo "        .await;" >> "$CRUD_FILE"
else
    echo "    let query = \"INSERT INTO ${TABLE_NAME} DEFAULT VALUES RETURNING *\";" >> "$CRUD_FILE"
    echo "" >> "$CRUD_FILE"
    echo "    let result = sqlx::query_as::<_, ${STRUCT_NAME}>(query)" >> "$CRUD_FILE"
    echo "        .fetch_one(pool.get_ref())" >> "$CRUD_FILE"
    echo "        .await;" >> "$CRUD_FILE"
fi

cat >> "$CRUD_FILE" << EOF

    match result {
        Ok(record) => Ok(web::Json(record)),
        Err(e) => {
            eprintln!("Database error: {}", e);
            Err(actix_web::error::ErrorInternalServerError("Failed to create record"))
        }
    }
}

async fn get_${PROJECT_NAME_UNDERSCORE}(
    pool: web::Data<PgPool>,
    id: web::Path<i32>,
) -> Result<impl Responder> {
    let result = sqlx::query_as::<_, ${STRUCT_NAME}>(
        "SELECT * FROM ${TABLE_NAME} WHERE id = \$1"
    )
    .bind(id.into_inner())
    .fetch_optional(pool.get_ref())
    .await;

    match result {
        Ok(Some(record)) => Ok(web::Json(record)),
        Ok(None) => Err(actix_web::error::ErrorNotFound("Record not found")),
        Err(e) => {
            eprintln!("Database error: {}", e);
            Err(actix_web::error::ErrorInternalServerError("Failed to get record"))
        }
    }
}

async fn list_${PROJECT_NAME_UNDERSCORE}(
    pool: web::Data<PgPool>,
) -> Result<impl Responder> {
    let result = sqlx::query_as::<_, ${STRUCT_NAME}>(
        "SELECT * FROM ${TABLE_NAME} ORDER BY id"
    )
    .fetch_all(pool.get_ref())
    .await;

    match result {
        Ok(records) => Ok(web::Json(records)),
        Err(e) => {
            eprintln!("Database error: {}", e);
            Err(actix_web::error::ErrorInternalServerError("Failed to list records"))
        }
    }
}

async fn update_${PROJECT_NAME_UNDERSCORE}(
    pool: web::Data<PgPool>,
    id: web::Path<i32>,
    record: web::Json<${REQUEST_NAME}>,
) -> Result<impl Responder> {
EOF

# Build UPDATE query dynamically
# changed_on is automatically updated by the database trigger, so we don't need to set it explicitly
if [ ${#FIELD_NAMES[@]} -gt 0 ]; then
    # Build SET clause using string concatenation
    echo "    let field_names: Vec<&str> = vec![" >> "$CRUD_FILE"
    for name in "${FIELD_NAMES[@]}"; do
        echo "        \"${name}\"," >> "$CRUD_FILE"
    done
    echo "    ];" >> "$CRUD_FILE"
    echo '    let set_clauses: Vec<String> = field_names.iter().enumerate().map(|(i, name)| format!("{} = ${}", name, i + 2)).collect();' >> "$CRUD_FILE"
    echo "    let set_clause = set_clauses.join(\", \");" >> "$CRUD_FILE"
    echo "    let query = format!(\"UPDATE ${TABLE_NAME} SET {} WHERE id = \$1 RETURNING *\", set_clause);" >> "$CRUD_FILE"
    echo "" >> "$CRUD_FILE"
    echo "    let result = sqlx::query_as::<_, ${STRUCT_NAME}>(&query)" >> "$CRUD_FILE"
    echo "        .bind(id.into_inner())" >> "$CRUD_FILE"
    for i in "${!FIELD_NAMES[@]}"; do
        FIELD_NAME="${FIELD_NAMES[$i]}"
        echo "        .bind(&record.${FIELD_NAME})" >> "$CRUD_FILE"
    done
    echo "        .fetch_optional(pool.get_ref())" >> "$CRUD_FILE"
    echo "        .await;" >> "$CRUD_FILE"
else
    # No fields to update, but trigger will still update changed_on
    echo "    let query = \"UPDATE ${TABLE_NAME} SET id = id WHERE id = \\$1 RETURNING *\";" >> "$CRUD_FILE"
    echo "" >> "$CRUD_FILE"
    echo "    let result = sqlx::query_as::<_, ${STRUCT_NAME}>(query)" >> "$CRUD_FILE"
    echo "        .bind(id.into_inner())" >> "$CRUD_FILE"
    echo "        .fetch_optional(pool.get_ref())" >> "$CRUD_FILE"
    echo "        .await;" >> "$CRUD_FILE"
fi

cat >> "$CRUD_FILE" << EOF

    match result {
        Ok(Some(record)) => Ok(web::Json(record)),
        Ok(None) => Err(actix_web::error::ErrorNotFound("Record not found")),
        Err(e) => {
            eprintln!("Database error: {}", e);
            Err(actix_web::error::ErrorInternalServerError("Failed to update record"))
        }
    }
}

async fn delete_${PROJECT_NAME_UNDERSCORE}(
    pool: web::Data<PgPool>,
    id: web::Path<i32>,
) -> Result<impl Responder> {
    let result = sqlx::query("DELETE FROM ${TABLE_NAME} WHERE id = \$1")
        .bind(id.into_inner())
        .execute(pool.get_ref())
        .await;

    match result {
        Ok(rows) => {
            if rows.rows_affected() > 0 {
                Ok(web::Json(serde_json::json!({"message": "Record deleted"})))
            } else {
                Err(actix_web::error::ErrorNotFound("Record not found"))
            }
        }
        Err(e) => {
            eprintln!("Database error: {}", e);
            Err(actix_web::error::ErrorInternalServerError("Failed to delete record"))
        }
    }
}
EOF

# Now update main.rs
echo "Updating main.rs..."

# Backup main.rs
cp main.rs main.rs.bak

# Step 1: Remove any existing generated code to avoid duplicates
# Remove from "// Generated by setup-db.sh" until we hit "#[actix_web::main]" or "async fn main()"
if grep -q "// Generated by setup-db.sh" main.rs; then
    awk '
        /^\/\/ Generated by setup-db\.sh/ { skip=1; next }
        skip && (/^#\[actix_web::main\]/ || /^async fn main\(\)/) { skip=0 }
        !skip { print }
    ' main.rs > main.rs.tmp && mv main.rs.tmp main.rs
fi

# Step 2: Remove any misplaced #[actix_web::main] that's not immediately before "async fn main"
# We'll add it back in the right place in step 4
sed -i.bak2 '/^#\[actix_web::main\]$/d' main.rs

# Step 3: Insert the generated code before "async fn main"
# Use awk to properly insert BEFORE the "async fn main" line
awk -v crud_file="$CRUD_FILE" '
    /^async fn main/ {
        # Read and print the generated CRUD code
        while ((getline line < crud_file) > 0) {
            print line
        }
        close(crud_file)
        print ""  # Add blank line before main
    }
    { print }
' main.rs > main.rs.tmp && mv main.rs.tmp main.rs

# Step 4: Ensure #[actix_web::main] is present right before async fn main
# Check if the line immediately before "async fn main" contains "#[actix_web::main]"
if ! grep -B1 "^async fn main" main.rs | head -1 | grep -q "#\[actix_web::main\]"; then
    # Add #[actix_web::main] right before async fn main using awk
    awk '
        /^async fn main/ {
            print "#[actix_web::main]"
        }
        { print }
    ' main.rs > main.rs.tmp && mv main.rs.tmp main.rs
fi

# Clean up backup files
rm -f main.rs.bak2

# Create routes file
ROUTES_FILE=$(mktemp)
cat > "$ROUTES_FILE" << ROUTES_EOF
                .route("/${PROJECT_NAME_UNDERSCORE}", web::post().to(create_${PROJECT_NAME_UNDERSCORE}))
                .route("/${PROJECT_NAME_UNDERSCORE}", web::get().to(list_${PROJECT_NAME_UNDERSCORE}))
                .route("/${PROJECT_NAME_UNDERSCORE}/{id}", web::get().to(get_${PROJECT_NAME_UNDERSCORE}))
                .route("/${PROJECT_NAME_UNDERSCORE}/{id}", web::put().to(update_${PROJECT_NAME_UNDERSCORE}))
                .route("/${PROJECT_NAME_UNDERSCORE}/{id}", web::delete().to(delete_${PROJECT_NAME_UNDERSCORE}))
ROUTES_EOF

# Update the main function to add routes
# First, remove any existing routes for this table to avoid duplicates
sed -i.bak5 "/\.route(\"\/${PROJECT_NAME_UNDERSCORE}/d" main.rs

# Find the service scope and add the CRUD routes using awk
if grep -q '\.route("/db"' main.rs; then
    # Insert routes after the /db route using awk
    awk -v routes_file="$ROUTES_FILE" '
        /\.route\("\/db"/ {
            print
            # Read and print the routes
            while ((getline line < routes_file) > 0) {
                print line
            }
            close(routes_file)
            next
        }
        { print }
    ' main.rs > main.rs.tmp && mv main.rs.tmp main.rs
elif grep -q '\.wrap(AuthMiddleware' main.rs; then
    # Insert after the .wrap(AuthMiddleware...) line if it exists
    awk -v routes_file="$ROUTES_FILE" '
        /\.wrap\(AuthMiddleware/ {
            print
            # Read and print the routes
            while ((getline line < routes_file) > 0) {
                print line
            }
            close(routes_file)
            next
        }
        { print }
    ' main.rs > main.rs.tmp && mv main.rs.tmp main.rs
elif grep -q 'web::scope("/api")' main.rs; then
    # Insert after the first route in the API scope (fallback)
    awk -v routes_file="$ROUTES_FILE" '
        !done && /\.service\(web::scope\("\/api"\)/ {
            in_scope = 1
        }
        !done && in_scope && /\.route\(/ {
            print
            # Read and print the routes
            while ((getline line < routes_file) > 0) {
                print line
            }
            close(routes_file)
            done = 1
            next
        }
        { print }
    ' main.rs > main.rs.tmp && mv main.rs.tmp main.rs
else
    echo -e "${YELLOW}Warning: Could not find API scope in main.rs. Please add routes manually.${NC}"
    echo "Routes to add:"
    cat "$ROUTES_FILE"
fi

# Clean up temporary files
rm -f main.rs.bak5 "$ROUTES_FILE" "$CRUD_FILE"

echo -e "${GREEN}✓ CRUD operations added to main.rs!${NC}"
echo ""
echo -e "${BLUE}Available endpoints:${NC}"
echo "  POST   /api/${PROJECT_NAME_UNDERSCORE}     - Create a new record"
echo "  GET    /api/${PROJECT_NAME_UNDERSCORE}     - List all records"
echo "  GET    /api/${PROJECT_NAME_UNDERSCORE}/{id} - Get a specific record"
echo "  PUT    /api/${PROJECT_NAME_UNDERSCORE}/{id} - Update a record"
echo "  DELETE /api/${PROJECT_NAME_UNDERSCORE}/{id} - Delete a record"
echo ""
echo -e "${GREEN}Setup complete!${NC}"
