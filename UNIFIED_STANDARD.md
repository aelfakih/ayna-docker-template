# Ayna Deployment Standard v2.0

**Replaces**: Docker Template v1.0.0
**Based on**: ayna-comply's proven Poe + systemd approach

## Overview

This standard defines the deployment pattern for all Ayna Python projects. It uses:

- **Makefile** - Universal command interface (what you type)
- **Poe the Poet** - Task orchestration (what runs underneath)
- **systemd** - Process management
- **venv/uv** - Python environment isolation
- **Symlink releases** - Blue-green deployment

No Docker required. Direct process management for simpler debugging.

---

## Directory Structure

```
/opt/ayna/{project}/
├── releases/               # Versioned releases (blue-green)
│   ├── v1/
│   ├── v2/
│   └── current -> v2       # Symlink to active release
├── shared/                 # Persistent across releases
│   ├── media/              # User uploads
│   ├── backups/            # Database backups
│   ├── .env.dev
│   ├── .env.staging
│   └── .env.production
├── venv/                   # Python virtual environment
├── logs/                   # Application logs
│
├── Makefile                # Universal command interface
├── pyproject.toml          # Poe tasks + dependencies
├── validate.sh             # Conformance checker
├── .template-version       # Tracks standard version
│
├── scripts/
│   └── poe_commands.py     # Poe task implementations
├── systemd/                # Service unit files
│   ├── {project}-web.service
│   ├── {project}-api.service      # If applicable
│   ├── {project}-celery.service
│   └── {project}-beat.service
│
└── src/                    # Application code
    ├── web/                # Django app
    ├── api/                # FastAPI app (if applicable)
    └── ...
```

---

## Port Registry

Each project gets 10 ports. All bind to `127.0.0.1` only.

| Project | Range | Web | API | Docs | Reserved |
|---------|-------|-----|-----|------|----------|
| ayna-comply | 8100-8109 | 8100 | 8101 | 8102 | 8103-8109 |
| ayna-fly | 8110-8119 | 8110 | 8111 | 8112 | 8113-8119 |
| aynasite | 8120-8129 | 8120 | 8121 | 8122 | 8123-8129 |
| uavcrew | 8130-8139 | 8130 | 8131 | 8132 | 8133-8139 |
| skybookus | 8140-8149 | 8140 | 8141 | 8142 | 8143-8149 |

### Port Convention (within each range)

| Offset | Purpose |
|--------|---------|
| +0 | Web/Frontend (Django) |
| +1 | API (FastAPI) |
| +2 | Documentation (Sphinx) |
| +3 | WebSocket |
| +4 | Admin/Internal |
| +5-9 | Reserved |

---

## Required Makefile Targets

Every project MUST implement these targets:

| Target | Description | Poe Equivalent |
|--------|-------------|----------------|
| `make run` | Start development server | `poe dev` |
| `make deploy` | Blue-green deployment | `poe deploy` |
| `make rollback` | Instant rollback | `poe rollback` |
| `make migrate` | Database migrations | `poe migrate` |
| `make shell` | Application shell | `poe shell` |
| `make logs` | Stream service logs | `poe logs` |
| `make start` | Start all services | `poe services:start` |
| `make stop` | Stop all services | `poe services:stop` |
| `make restart` | Restart all services | `poe services:restart` |
| `make status` | Show service status | `poe services:status` |
| `make validate` | Check conformance | `./validate.sh` |

### Template Makefile

```makefile
# Ayna Deployment Standard v2.0
# Makefile wraps Poe tasks for universal interface

PROJECT_NAME ?= myproject
WEB_PORT ?= 8100
API_PORT ?= 8101

GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

.PHONY: run deploy rollback migrate shell logs start stop restart status validate help

# Development
run:
	@poe dev

# Deployment
deploy:
	@poe deploy production

rollback:
	@poe rollback

# Database
migrate:
	@poe migrate

# Shell access
shell:
	@poe shell

# Service management
start:
	@poe services:start

stop:
	@poe services:stop

restart:
	@poe services:restart

status:
	@poe services:status

logs:
	@poe logs

# Validation
validate:
	@./validate.sh

# Testing
test:
	@poe test

lint:
	@poe lint

# Help
help:
	@echo "$(GREEN)$(PROJECT_NAME) - Ayna Deployment Standard v2.0$(NC)"
	@echo ""
	@echo "Development:"
	@echo "  make run        Start development server"
	@echo "  make test       Run tests"
	@echo "  make lint       Run linters"
	@echo ""
	@echo "Deployment:"
	@echo "  make deploy     Blue-green deployment to production"
	@echo "  make rollback   Instant rollback to previous version"
	@echo ""
	@echo "Services:"
	@echo "  make start      Start all services"
	@echo "  make stop       Stop all services"
	@echo "  make restart    Restart all services"
	@echo "  make status     Show service status"
	@echo "  make logs       Stream logs"
	@echo ""
	@echo "Database:"
	@echo "  make migrate    Run migrations"
	@echo "  make shell      Django/Python shell"
```

---

## Systemd Service Pattern

### Web Service (Django/Gunicorn)

```ini
# /etc/systemd/system/{project}-web.service
[Unit]
Description={Project} Web Server
After=network.target postgresql.service redis.service

[Service]
Type=notify
User=adonis
Group=adonis
WorkingDirectory=/opt/ayna/{project}/releases/current
Environment="PATH=/opt/ayna/{project}/venv/bin"
EnvironmentFile=/opt/ayna/{project}/shared/.env.production
ExecStart=/opt/ayna/{project}/venv/bin/gunicorn \
    --bind 127.0.0.1:{WEB_PORT} \
    --workers 4 \
    --timeout 120 \
    config.wsgi:application
ExecReload=/bin/kill -s HUP $MAINPID
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```

### API Service (FastAPI/Uvicorn)

```ini
# /etc/systemd/system/{project}-api.service
[Unit]
Description={Project} API Server
After=network.target postgresql.service redis.service

[Service]
Type=simple
User=adonis
Group=adonis
WorkingDirectory=/opt/ayna/{project}/releases/current
Environment="PATH=/opt/ayna/{project}/venv/bin"
EnvironmentFile=/opt/ayna/{project}/shared/.env.production
ExecStart=/opt/ayna/{project}/venv/bin/uvicorn \
    --host 127.0.0.1 \
    --port {API_PORT} \
    --workers 2 \
    api.main:app
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```

### Celery Worker

```ini
# /etc/systemd/system/{project}-celery.service
[Unit]
Description={Project} Celery Worker
After=network.target redis.service

[Service]
Type=simple
User=adonis
Group=adonis
WorkingDirectory=/opt/ayna/{project}/releases/current
Environment="PATH=/opt/ayna/{project}/venv/bin"
EnvironmentFile=/opt/ayna/{project}/shared/.env.production
ExecStart=/opt/ayna/{project}/venv/bin/celery \
    -A config worker \
    -l INFO \
    --concurrency=4
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```

---

## Blue-Green Deployment

The `make deploy` (via `poe deploy`) process:

```
1. Create new release directory (releases/v{N+1}/)
2. Git pull or copy code
3. Install/update dependencies in venv
4. Run database migrations
5. Collect static files
6. Switch symlink: current -> v{N+1}
7. Reload services (systemctl reload)
8. Health check
9. If unhealthy: automatic rollback
```

### Rollback

Instant rollback via symlink switch:

```bash
# Automatic (in poe rollback)
current -> v{N-1}
systemctl reload {project}-web
```

---

## Environment Configuration

### .env Files

Located in `shared/` directory, never in git:

```
shared/
├── .env.dev           # Development (local)
├── .env.staging       # Staging server
└── .env.production    # Production server
```

### Required Variables

```bash
# Core
PROJECT_NAME=myproject
DJANGO_SETTINGS_MODULE=config.settings.production
SECRET_KEY=...

# Database
DATABASE_URL=postgresql://user:pass@localhost:5432/dbname

# Redis
REDIS_URL=redis://localhost:6379/0

# Ports (match PORT_REGISTRY)
WEB_PORT=8130
API_PORT=8131
```

---

## Conformance Validation

The `validate.sh` script checks:

1. Required files exist (Makefile, pyproject.toml, .template-version)
2. Required directories exist (scripts/, systemd/)
3. Makefile has all required targets
4. Poe tasks are defined in pyproject.toml
5. Systemd units exist
6. Port assignments match registry
7. Environment files documented

```bash
./validate.sh

# Output:
# ✓ Makefile exists
# ✓ pyproject.toml has [tool.poe.tasks]
# ✓ make deploy target defined
# ✓ systemd/myproject-web.service exists
# ✓ Port 8130 matches registry for myproject
# ...
```

---

## Migration from Docker Template

For projects currently using Docker (like uavcrew):

### 1. Create systemd services

```bash
# Create service files
sudo cp systemd/*.service /etc/systemd/system/
sudo systemctl daemon-reload
```

### 2. Set up releases structure

```bash
mkdir -p /opt/ayna/{project}/releases
mkdir -p /opt/ayna/{project}/shared/{media,backups}
```

### 3. Create venv

```bash
python3.12 -m venv /opt/ayna/{project}/venv
source /opt/ayna/{project}/venv/bin/activate
pip install -r requirements.txt
```

### 4. Update Makefile

Replace docker compose calls with poe calls.

### 5. Remove Docker artifacts

```bash
rm -rf docker/ compose/
# Keep caddy/ if using Caddy on host
```

---

## Migration for ayna-comply

Already follows this standard. Only changes needed:

1. **Port alignment**: Update from 8001 to 8100 (per registry)
2. **Add Makefile**: Thin wrapper around existing Poe tasks
3. **Add validate.sh**: Conformance checker
4. **Add .template-version**: Track standard version

Estimated effort: **2-3 hours**

---

## Version History

- **2.0.0** - Unified standard (Makefile + Poe + systemd)
  - Replaces Docker-based v1.0.0
  - Based on ayna-comply's proven approach
  - Adds port registry from Docker template
  - Adds conformance validation
