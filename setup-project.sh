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
    # Escape special characters for sed
    POSTGRES_USER_ESC=$(echo "$POSTGRES_USER" | sed 's/[[\.*^$()+?{|]/\\&/g')
    POSTGRES_PASSWORD_ESC=$(echo "$POSTGRES_PASSWORD" | sed 's/[[\.*^$()+?{|]/\\&/g')
    POSTGRES_DB_ESC=$(echo "$POSTGRES_DB" | sed 's/[[\.*^$()+?{|]/\\&/g')
    DOMAIN_ESC=$(echo "$DOMAIN" | sed 's/[[\.*^$()+?{|]/\\&/g')
    
    sed -i.bak \
        -e "s/actix-server-postgres/${PROJECT_NAME_HYPHEN}-postgres/g" \
        -e "s/actix_server_postgres/${PROJECT_NAME_UNDERSCORE}_postgres/g" \
        -e "s/actix_server_postgres_data/${PROJECT_NAME_UNDERSCORE}_postgres_data/g" \
        -e "s/actix-server:/${PROJECT_NAME_HYPHEN}:/g" \
        -e "s/actix_server/${PROJECT_NAME_UNDERSCORE}/g" \
        -e "s/actix-server/${PROJECT_NAME_HYPHEN}/g" \
        -e "s/8083:8080/${HOST_PORT}:8080/g" \
        -e "s/5433:5432/${DB_HOST_PORT}:5432/g" \
        -e "s/actix\.ernilabs\.com/${DOMAIN_ESC}/g" \
        -e "s/POSTGRES_USER: actix_user/POSTGRES_USER: ${POSTGRES_USER_ESC}/g" \
        -e "s/POSTGRES_PASSWORD: actix_password/POSTGRES_PASSWORD: ${POSTGRES_PASSWORD_ESC}/g" \
        -e "s/POSTGRES_DB: actix_db/POSTGRES_DB: ${POSTGRES_DB_ESC}/g" \
        -e "s/actix_user:actix_password@/${POSTGRES_USER_ESC}:${POSTGRES_PASSWORD_ESC}@/g" \
        -e "s|/actix_db|/${POSTGRES_DB_ESC}|g" \
        -e "s/pg_isready -U actix_user -d actix_db/pg_isready -U ${POSTGRES_USER_ESC} -d ${POSTGRES_DB_ESC}/g" \
        docker-compose.yml
    rm -f docker-compose.yml.bak
else
    echo "  - Warning: docker-compose.yml not found"
fi

# Update Cargo.toml
if [ -f "Cargo.toml" ]; then
    echo "  - Updating Cargo.toml"
    sed -i.bak \
        -e "s/name = \"actix-server\"/name = \"${PROJECT_NAME_HYPHEN}\"/g" \
        Cargo.toml
    rm -f Cargo.toml.bak
else
    echo "  - Warning: Cargo.toml not found"
fi

# Update Dockerfile
if [ -f "Dockerfile" ]; then
    echo "  - Updating Dockerfile"
    sed -i.bak \
        -e "s/actix-server/${PROJECT_NAME_HYPHEN}/g" \
        Dockerfile
    rm -f Dockerfile.bak
else
    echo "  - Warning: Dockerfile not found"
fi

echo ""
echo -e "${GREEN}✓ Setup complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Review the changes in docker-compose.yml, Cargo.toml, and Dockerfile"
echo "  2. Update main.rs with your application code - see/run setup-db.sh"
echo "  3. Run: docker-compose up --build"
echo ""

