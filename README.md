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
   - `main.rs` (creates fresh template with database connection)

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

The `setup-db.sh` script then adds:
- Database table structs
- CRUD operation functions
- API routes for your table

## Quick Checklist for New Projects

- [ ] Run `./scripts/setup-project.sh` to configure the project
- [ ] Run `docker-compose up --build -d` to start services
- [ ] Run `./scripts/setup-db.sh` to create your database table
- [ ] Rebuild with `docker-compose down && docker-compose up --build -d`
- [ ] Test your API endpoints

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
└── README.md                 # This file
```

## Example Routes

The template includes several example routes:

1. **GET /** - Root endpoint
   - Returns: `"Hello from Actix Web!"`
   - Example: `curl http://localhost:8083/`

2. **GET /health** - Health check endpoint
   - Returns: `"OK"`
   - Example: `curl http://localhost:8083/health`

3. **GET /api/name/{name}** - Dynamic route with path parameter
   - Returns: `"Hello, {name}!"`
   - Example: `curl http://localhost:8083/api/name/World`
   - Response: `"Hello, World!"`

4. **GET /api/db** - Database connection check
   - Returns: Database connection status and PostgreSQL version
   - Example: `curl http://localhost:8083/api/db`

5. **CRUD Routes** (generated by `setup-db.sh` for your table):
   - **POST** `/api/{table-name}` - Create a new record
   - **GET** `/api/{table-name}` - List all records
   - **GET** `/api/{table-name}/{id}` - Get a specific record
   - **PUT** `/api/{table-name}/{id}` - Update a record
   - **DELETE** `/api/{table-name}/{id}` - Delete a record
   
   Example (if your table is `users`):
   ```bash
   # Create
   curl -X POST http://localhost:8083/api/users \
     -H "Content-Type: application/json" \
     -d '{"name": "John", "age": 30, "aktiv": true}'
   
   # List all
   curl http://localhost:8083/api/users
   
   # Get by ID
   curl http://localhost:8083/api/users/1
   
   # Update
   curl -X PUT http://localhost:8083/api/users/1 \
     -H "Content-Type: application/json" \
     -d '{"name": "Jane", "age": 25, "aktiv": false}'
   
   # Delete
   curl -X DELETE http://localhost:8083/api/users/1
   ```

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
- **sqlx** (0.7) - Async PostgreSQL driver with compile-time SQL checking
- **tokio** (1.x) - Async runtime
- **chrono** (0.4) - Date and time handling
- **serde** (1.0) - Serialization framework
- **serde_json** (1.0) - JSON support

All dependencies are configured in `Cargo.toml`.
