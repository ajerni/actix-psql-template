# Rust Actix Web Server with PostgreSQL - Docker Compose Template

This template provides a ready-to-use Docker Compose setup for a Rust Actix Web server with PostgreSQL database integration and Traefik support.

## Quick Start

### Automated Setup (Recommended)

1. **Copy this template** to a new directory for your project:
   ```bash
   cp -r actix-template my-new-project
   cd my-new-project
   ```

2. Run the setup script to configure your project:
   ```bash
   ./scripts/setup-project.sh
   ```
   The script will ask for:
   - Project name (e.g., `my-api`, `user-service`)
   - PostgreSQL username (default: `{project-name}_user`)
   - PostgreSQL password
   - Database host port mapping (default: 5433)
   - Host port (default: 8083)
   - Domain (default: `{project-name}.ernilabs.com`)

   It will automatically update:
   - `docker-compose.yml` (service names, container names, ports, database config, Traefik labels)
   - `Cargo.toml` (package name and binary name)
   - `Dockerfile` (binary references)
   - `main.rs` (creates fresh template with database connection and API authentication middleware)

3. Build and run the containers:
   ```bash
   docker-compose up --build -d
   ```

4. Set up your database table:
   ```bash
   ./scripts/setup-db.sh
   ```
   This interactive script will:
   - Ask you to define table fields (name, type)
   - Create the PostgreSQL table with automatic `id`, `created_on`, and `changed_on` fields
   - Generate CRUD (Create, Read, Update, Delete) operations in `main.rs`
   - Add API routes for your table

5. Rebuild and restart to include the new database code:
   ```bash
   docker-compose down
   docker-compose up --build -d
   ```

6. The server will be available at your configured domain through Traefik with TLS.

**Note:** The API key for authentication will be displayed in the server logs when it starts. View logs with `docker-compose logs {project-name}` to see the `x-api-key` value. All routes under `/api/*` require the `x-api-key` header.

## Database Management

### Creating a Database Table

Run the interactive setup script:
```bash
./scripts/setup-db.sh
```

The script will:
1. Extract your project name from `Cargo.toml`
2. Ask you to define table fields interactively
3. Create the PostgreSQL table with:
   - `id` (SERIAL PRIMARY KEY)
   - `created_on` (TIMESTAMP, auto-set on creation)
   - `changed_on` (TIMESTAMP, auto-updated via trigger)
   - Your custom fields
4. Generate complete CRUD operations in `main.rs`
5. Add API routes to your Actix application

### Deleting a Database Table

To remove a table and optionally clean up the generated code:
```bash
./scripts/delete-db.sh
```

This will:
1. Drop the database table
2. Optionally remove generated CRUD code from `main.rs`
3. Clean up routes

### Manual Setup

If you prefer to customize manually, see the "Customizing for New Projects" section below.

## Customizing for New Projects

When creating a new project from this template, you need to update the following:

### 1. **docker-compose.yml**

The `setup-project.sh` script automatically updates:
- **Service names** (Actix and PostgreSQL services)
- **Container names** (both services)
- **Port mappings** (Actix host port and PostgreSQL host port)
- **Database configuration** (user, password, database name)
- **Traefik labels** (domain, router names, service names)
- **Volume names** (PostgreSQL data volume)

If updating manually, ensure all service/container names are prefixed with your project name.

### 2. **Cargo.toml**

The `setup-project.sh` script automatically updates:
- **Package name** (line 2)
- **Binary name** (line 7)

### 3. **Dockerfile**

The `setup-project.sh` script automatically updates binary references. No manual changes needed.

### 4. **main.rs**

The `setup-project.sh` script creates a fresh template with:
- Basic Actix Web routes
- Database connection setup
- Health check endpoints
- API authentication middleware (protects all `/api/*` routes)
- API key: `{project-name}-apisecret`

The `setup-db.sh` script then adds:
- Database table structs
- CRUD operation functions
- API routes for your table (automatically protected by the middleware)

## Quick Checklist for New Projects

- [ ] Run `./scripts/setup-project.sh` to configure the project
- [ ] Run `docker-compose up --build -d` to start services
- [ ] View logs to see API key: `docker-compose logs {project-name}` (format: `{project-name}-apisecret`)
- [ ] Run `./scripts/setup-db.sh` to create your database table
- [ ] Rebuild with `docker-compose down && docker-compose up --build -d`
- [ ] Test your API endpoints (remember to include `x-api-key` header for `/api/*` routes)

## Project Structure

```
.
├── docker-compose.yml       # Docker Compose configuration (Actix + PostgreSQL + Traefik)
├── Dockerfile                # Multi-stage build for Rust application
├── Cargo.toml                # Rust project dependencies (includes sqlx, actix-web, etc.)
├── main.rs                   # Your Actix Web application code (with database integration)
├── scripts/
│   ├── setup-project.sh      # Automated project setup script
│   ├── setup-db.sh           # Interactive database table creation and CRUD code generation
│   └── delete-db.sh          # Database table deletion and code cleanup script
├── traefik_configuration/    # Traefik configuration reference files (for documentation)
│   ├── traefik_backup.yml    # Main Traefik configuration reference
│   ├── traefik_api_backup.yml # Traefik API dashboard configuration reference
│   ├── docker-compose_backup.yml # Traefik Docker Compose reference
│   └── acme.json             # Let's Encrypt certificate storage (empty)
└── README.md                 # This file
```

## Authentication

All routes under `/api/*` are protected by API key authentication. The authentication middleware checks for the `x-api-key` header.

**API Key Format:** `{project-name}-apisecret`

For example, if your project name is `my-api`, your API key will be: `my-api-apisecret`

**Public Routes** (no authentication required):
- `GET /` - Root endpoint
- `GET /health` - Health check endpoint

**Protected Routes** (require `x-api-key` header):
- All routes under `/api/*`

**Usage:**
```bash
# Public route (no auth needed)
curl http://localhost:8083/health

# Protected route (requires API key)
curl -H "x-api-key: my-api-apisecret" http://localhost:8083/api/db
```

The API key is displayed in the server logs when it starts:
```
✓ Database connection established
===========================================
✓ x-api-key: my-api-apisecret
===========================================
```

## Example Routes

The template includes several example routes:

1. **GET /** - Root endpoint (Public)
   - Returns: `"Hello from Actix Web!"`
   - Example: `curl http://localhost:8083/`

2. **GET /health** - Health check endpoint (Public)
   - Returns: `"OK"`
   - Example: `curl http://localhost:8083/health`

3. **GET /api/name/{name}** - Dynamic route with path parameter (Protected)
   - Returns: `"Hello, {name}!"`
   - Example: `curl -H "x-api-key: my-api-apisecret" http://localhost:8083/api/name/World`
   - Response: `"Hello, World!"`

4. **GET /api/db** - Database connection check (Protected)
   - Returns: Database connection status and PostgreSQL version
   - Example: `curl -H "x-api-key: my-api-apisecret" http://localhost:8083/api/db`

5. **CRUD Routes** (generated by `setup-db.sh` for your table) - All Protected:
   - **POST** `/api/{table-name}` - Create a new record
   - **GET** `/api/{table-name}` - List all records
   - **GET** `/api/{table-name}/{id}` - Get a specific record
   - **PUT** `/api/{table-name}/{id}` - Update a record
   - **DELETE** `/api/{table-name}/{id}` - Delete a record
   
   Example (if your table is `users` and project name is `my-api`):
   ```bash
   # Create
   curl -X POST http://localhost:8083/api/users \
     -H "x-api-key: my-api-apisecret" \
     -H "Content-Type: application/json" \
     -d '{"name": "John", "age": 30, "aktiv": true}'
   
   # List all
   curl -H "x-api-key: my-api-apisecret" http://localhost:8083/api/users
   
   # Get by ID
   curl -H "x-api-key: my-api-apisecret" http://localhost:8083/api/users/1
   
   # Update
   curl -X PUT http://localhost:8083/api/users/1 \
     -H "x-api-key: my-api-apisecret" \
     -H "Content-Type: application/json" \
     -d '{"name": "Jane", "age": 25, "aktiv": false}'
   
   # Delete
   curl -X DELETE -H "x-api-key: my-api-apisecret" http://localhost:8083/api/users/1
   ```
**CREATE YOUR FRONTEND: Put this in a text file and give your favourite LLM a prompt like:**

   "see available api end points in @api_routes.txt and write a simple but nice looking frontend (one index.html file) that allows for these CRUD operations (including edit area on top and display area below)"

## Database Configuration

The template includes PostgreSQL 16 with:
- Automatic timestamp fields (`created_on`, `changed_on`)
- Database triggers for auto-updating `changed_on` on record updates
- Connection pooling via `sqlx`
- Health checks for database readiness

Database connection details are configured in `docker-compose.yml` and passed to the Actix application via the `DATABASE_URL` environment variable.

## Network Configuration

This template uses the `iotnetwork` external network for Traefik integration. Make sure this network exists on your server:

```bash
docker network create iotnetwork
```

## Traefik Configuration Reference

The `traefik_configuration/` directory contains reference files showing how Traefik is configured on the server. These files are provided for reference only and are not used by this template directly.

**Files in `traefik_configuration/`:**

- **`traefik_backup.yml`** - Main Traefik configuration file with:
  - Entry points (HTTP on port 81 with HTTPS redirect, HTTPS on port 443)
  - API dashboard enabled
  - Let's Encrypt certificate resolver (`lets-encrypt`)
  - Docker provider watching the `iotnetwork`
  - File provider for additional configuration

- **`traefik_api_backup.yml`** - Traefik API dashboard configuration:
  - Basic authentication for the dashboard
  - Router configuration for `traefik.ernilabs.com`
  - TLS/HTTPS setup with Let's Encrypt

- **`docker-compose_backup.yml`** - Docker Compose file for running Traefik:
  - Traefik container configuration
  - Network and volume mounts
  - Port mappings (81 for HTTP, 443 for HTTPS)

- **`acme.json`** - Let's Encrypt certificate storage file (empty, created by Traefik)

**How it works:**

When you run `setup-project.sh`, the generated `docker-compose.yml` includes Traefik labels that automatically configure routing:
- Domain-based routing (e.g., `{project-name}.ernilabs.com`)
- Automatic TLS/HTTPS via Let's Encrypt
- Service discovery through Docker labels

The Traefik instance (running separately) reads these labels and automatically:
1. Creates routes for your service
2. Obtains SSL certificates from Let's Encrypt
3. Routes HTTPS traffic to your Actix application

**Note:** These reference files show the server's Traefik setup. Your Actix service doesn't need to run Traefik itself—it just needs to be on the same `iotnetwork` and have the correct labels in `docker-compose.yml` (which `setup-project.sh` generates automatically).

## Local Testing

For local testing, create the `iotnetwork` manually once (it only needs to be done once):

```bash
docker network create iotnetwork
docker-compose up --build
```

The server will be accessible at `http://localhost:8083` (or your configured port).

**Note:** The network will persist after creation, so you only need to create it once. If you want to remove it later:
```bash
docker network rm iotnetwork
```

**On your server:**
- The `iotnetwork` already exists as an external network
- Just run `docker-compose up --build` as normal

## Deployment to Server

To upload your files to your vserver via SSH, you have several options:

### Option 1: rsync

```bash
# On your local machine
# Option 1: Navigate first, then sync
cd /Users/andi/projekte/test
rsync -avz --exclude 'target' --exclude '.git' ./ user@server.com:/usr/local/sbin
```

### Option 2: Git (If using version control)

If you're using git, clone on the server:

```bash
# On your server
git clone your-repo-url
cd project-name
```

## Dependencies

The template includes the following Rust dependencies:

- **actix-web** (4.4) - Web framework
- **actix-rt** (2.9) - Runtime support
- **actix-cors** (0.7) - CORS middleware support
- **sqlx** (0.7) - Async PostgreSQL driver with compile-time SQL checking
- **tokio** (1.x) - Async runtime
- **chrono** (0.4) - Date and time handling
- **serde** (1.0) - Serialization framework
- **serde_json** (1.0) - JSON support
- **futures-util** (0.3) - Future utilities for async middleware

All dependencies are configured in `Cargo.toml`.
