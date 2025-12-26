#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Actix Web Project Setup Script${NC}"
echo "=================================="
echo ""

# Get project name
read -p "Enter project name (e.g., my-api, user-service): " PROJECT_NAME
if [ -z "$PROJECT_NAME" ]; then
    echo "Error: Project name cannot be empty"
    exit 1
fi

# Convert project name to different formats
PROJECT_NAME_UNDERSCORE=$(echo "$PROJECT_NAME" | tr '-' '_')
PROJECT_NAME_HYPHEN=$(echo "$PROJECT_NAME" | tr '_' '-')

# Get database settings
read -p "Enter PostgreSQL username (default: ${PROJECT_NAME_UNDERSCORE}_user): " POSTGRES_USER
POSTGRES_USER=${POSTGRES_USER:-${PROJECT_NAME_UNDERSCORE}_user}

read -p "Enter PostgreSQL password: " POSTGRES_PASSWORD
if [ -z "$POSTGRES_PASSWORD" ]; then
    echo "Error: PostgreSQL password cannot be empty"
    exit 1
fi

read -p "Enter database host port mapping (default: 5433): " DB_HOST_PORT
DB_HOST_PORT=${DB_HOST_PORT:-5433}

# Database name will be {projectname}_db
POSTGRES_DB="${PROJECT_NAME_UNDERSCORE}_db"

# Get port
read -p "Enter host port (default: 8083): " HOST_PORT
HOST_PORT=${HOST_PORT:-8083}

# Get domain (optional, defaults to project-name.ernilabs.com)
read -p "Enter domain (default: ${PROJECT_NAME_HYPHEN}.ernilabs.com): " DOMAIN
DOMAIN=${DOMAIN:-${PROJECT_NAME_HYPHEN}.ernilabs.com}

echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  Project name: $PROJECT_NAME_HYPHEN"
echo "  Container name: $PROJECT_NAME_UNDERSCORE"
echo "  Host port: $HOST_PORT"
echo "  Domain: $DOMAIN"
echo "  PostgreSQL username: $POSTGRES_USER"
echo "  PostgreSQL database: $POSTGRES_DB"
echo "  Database host port: $DB_HOST_PORT:5432"
echo ""
read -p "Continue with these settings? (y/n): " CONFIRM

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Updating files..."

# Update docker-compose.yml
if [ -f "docker-compose.yml" ]; then
    echo "  - Updating docker-compose.yml"
    
    # Generate docker-compose.yml from template using the NEW project name
    # This approach doesn't detect old names - it just uses the new project name everywhere
    cat > docker-compose.yml << DOCKER_COMPOSE_EOF
version: "3.7"

services:
  ${PROJECT_NAME_HYPHEN}:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: ${PROJECT_NAME_UNDERSCORE}
    restart: always
    ports:
      - "${HOST_PORT}:8080"
    environment:
      DATABASE_URL: postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${PROJECT_NAME_HYPHEN}-postgres:5432/${POSTGRES_DB}
    networks:
      - iotnetwork
    labels:
      - traefik.enable=true
      - traefik.http.routers.${PROJECT_NAME_HYPHEN}.rule=Host(\`${DOMAIN}\`)
      - traefik.http.routers.${PROJECT_NAME_HYPHEN}.tls=true
      - traefik.http.routers.${PROJECT_NAME_HYPHEN}.tls.certresolver=lets-encrypt
      - traefik.http.services.${PROJECT_NAME_HYPHEN}.loadbalancer.server.port=8080
    depends_on:
      - ${PROJECT_NAME_HYPHEN}-postgres

  ${PROJECT_NAME_HYPHEN}-postgres:
    image: postgres:16-alpine
    container_name: ${PROJECT_NAME_UNDERSCORE}_postgres
    restart: always
    ports:
      - "${DB_HOST_PORT}:5432"
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    volumes:
      - ${PROJECT_NAME_UNDERSCORE}_postgres_data:/var/lib/postgresql/data
    networks:
      - iotnetwork
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5

networks:
  iotnetwork:
    external: true

volumes:
  ${PROJECT_NAME_UNDERSCORE}_postgres_data:
DOCKER_COMPOSE_EOF
    
else
    echo "  - Warning: docker-compose.yml not found"
fi

# Get current binary name from Cargo.toml BEFORE updating it (needed for Dockerfile update)
CURRENT_BIN_NAME=$(awk -F'"' '/^name =/ {print $2; exit}' Cargo.toml 2>/dev/null || echo "actix-server")

# Update Cargo.toml
if [ -f "Cargo.toml" ]; then
    echo "  - Updating Cargo.toml"
    # Update package name (line starting with name = in [package] section)
    # Update binary name (line starting with name = in [[bin]] section)
    sed -i.bak \
        -e "s/^name = \".*\"/name = \"${PROJECT_NAME_HYPHEN}\"/g" \
        Cargo.toml
    rm -f Cargo.toml.bak
else
    echo "  - Warning: Cargo.toml not found"
fi

# Update Dockerfile
if [ -f "Dockerfile" ]; then
    echo "  - Updating Dockerfile"
    # Escape special characters in binary name for sed
    CURRENT_BIN_NAME_ESC=$(echo "$CURRENT_BIN_NAME" | sed 's/[[\.*^$()+?{|]/\\&/g')
    # Replace current binary name (from Cargo.toml) and template placeholder with new project name
    # Handle different contexts: COPY paths, CMD brackets, and general replacements
    # Order matters: do specific patterns first, then general replacements
    # For CMD line: replace ANY binary name in CMD ["./binary"] format with new project name
    # For COPY line: replace ANY binary name in both source and destination paths
    sed -i.bak \
        -e "s|CMD \[\"\./[^\"]*\"\]|CMD \[\"\./${PROJECT_NAME_HYPHEN}\"\]|g" \
        -e "s|/target/release/[^ ]* /app/[^ ]*|/target/release/${PROJECT_NAME_HYPHEN} /app/${PROJECT_NAME_HYPHEN}|g" \
        -e "s|CMD \[\"\./${CURRENT_BIN_NAME}\"\]|CMD \[\"\./${PROJECT_NAME_HYPHEN}\"\]|g" \
        -e "s|CMD \[\"\./actix-server\"\]|CMD \[\"\./${PROJECT_NAME_HYPHEN}\"\]|g" \
        -e "s|/target/release/${CURRENT_BIN_NAME_ESC} /app/[^ ]*|/target/release/${PROJECT_NAME_HYPHEN} /app/${PROJECT_NAME_HYPHEN}|g" \
        -e "s|/target/release/${CURRENT_BIN_NAME_ESC}|/target/release/${PROJECT_NAME_HYPHEN}|g" \
        -e "s|/app/${CURRENT_BIN_NAME_ESC}|/app/${PROJECT_NAME_HYPHEN}|g" \
        -e "s|\"/app/${CURRENT_BIN_NAME_ESC}\"|\"/app/${PROJECT_NAME_HYPHEN}\"|g" \
        -e "s|\./${CURRENT_BIN_NAME_ESC}\"|./${PROJECT_NAME_HYPHEN}\"|g" \
        -e "s|/target/release/actix-server /app/[^ ]*|/target/release/${PROJECT_NAME_HYPHEN} /app/${PROJECT_NAME_HYPHEN}|g" \
        -e "s|/target/release/actix-server|/target/release/${PROJECT_NAME_HYPHEN}|g" \
        -e "s|/app/actix-server|/app/${PROJECT_NAME_HYPHEN}|g" \
        -e "s|\"/app/actix-server\"|\"/app/${PROJECT_NAME_HYPHEN}\"|g" \
        -e "s|\./actix-server\"|./${PROJECT_NAME_HYPHEN}\"|g" \
        Dockerfile
    rm -f Dockerfile.bak
else
    echo "  - Warning: Dockerfile not found"
fi

# Create/overwrite main.rs with fresh template
echo "  - Creating/updating main.rs"
cat > main.rs << MAIN_EOF
use actix_web::{web, App, HttpServer, Responder, Result};
use sqlx::{PgPool, Row};

async fn index() -> impl Responder {
    "Hello from Actix Web!"
}

async fn health() -> impl Responder {
    "OK"
}

async fn name(path: web::Path<String>) -> impl Responder {
    format!("Hello, {}!", path.into_inner())
}

async fn db_check(pool: web::Data<PgPool>) -> Result<impl Responder> {
    let result = sqlx::query("SELECT NOW() as current_time, version() as pg_version")
        .fetch_one(pool.get_ref())
        .await;

    match result {
        Ok(row) => {
            let current_time: chrono::DateTime<chrono::Utc> = row.get("current_time");
            let pg_version: String = row.get("pg_version");
            Ok(format!(
                "Database connected!\\nPostgreSQL version: {}\\nCurrent time: {}",
                pg_version, current_time
            ))
        }
        Err(e) => Ok(format!("Database error: {}", e)),
    }
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    // Database connection string
    // From within Docker network, use service name: ${PROJECT_NAME_HYPHEN}-postgres
    // From host machine, use: localhost:${DB_HOST_PORT}
    let database_url = std::env::var("DATABASE_URL")
        .unwrap_or_else(|_| "postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${PROJECT_NAME_HYPHEN}-postgres:5432/${POSTGRES_DB}".to_string());

    // Create database connection pool
    let pool = PgPool::connect(&database_url)
        .await
        .expect("Failed to connect to database");

    // Test the connection
    sqlx::query("SELECT 1")
        .execute(&pool)
        .await
        .expect("Failed to execute test query");

    println!("✓ Database connection established");

    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(pool.clone()))
            .service(web::scope("/api")
                .route("/name/{name}", web::get().to(name))
                .route("/db", web::get().to(db_check))
            )
            .route("/health", web::get().to(health))
            .route("/", web::get().to(index))
    })
    .bind("0.0.0.0:8080")?
    .run()
    .await
}
MAIN_EOF

echo ""
echo -e "${GREEN}✓ Setup complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Review the changes in docker-compose.yml, Cargo.toml, and Dockerfile"
echo "  2. Update main.rs with your application code or run setup-db.sh to create a fresh table"
echo "  3. Run: docker-compose up --build"
echo ""

