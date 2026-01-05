# Ayna Deployment Template

Standard deployment pattern for all Ayna Python projects.

## Version 2.0 - Unified Standard

**v2.0** replaces Docker with Poe + systemd for simpler debugging and maintenance.

See [UNIFIED_STANDARD.md](UNIFIED_STANDARD.md) for full specification.

### Why the Change?

- **Simpler debugging** - Direct process access, no container layers
- **Proven approach** - Based on ayna-comply's 288+ successful deployments
- **One mental model** - Same tools everywhere

## Quick Start

### New Project

```bash
./init.sh myproject ~/repos
cd ~/repos/myproject
```

### Existing Project

```bash
# Copy required files
cp -r /path/to/template/{Makefile,validate.sh,.env.example} .
cp -r /path/to/template/scripts .
mkdir -p systemd

# Track template version
echo "2.0.0" > .template-version

# Validate
make validate
```

## Standard Commands

| Command | Description |
|---------|-------------|
| `make run` | Start development server |
| `make deploy` | Blue-green deployment |
| `make rollback` | Instant rollback |
| `make migrate` | Database migrations |
| `make shell` | Application shell |
| `make start` | Start all services |
| `make stop` | Stop all services |
| `make restart` | Restart all services |
| `make status` | Show service status |
| `make logs` | Stream logs |
| `make validate` | Check conformance |

## Architecture

```
User types:     make deploy
                    ↓
Makefile calls: poe deploy production
                    ↓
Poe runs:       scripts/poe_commands.py
                    ↓
Which does:     git pull → migrate → symlink switch → systemctl reload
```

## Directory Structure

```
/opt/ayna/{project}/
├── releases/               # Versioned releases (blue-green)
│   ├── v1/
│   ├── v2/
│   └── current -> v2       # Symlink to active release
├── shared/                 # Persistent across releases
│   ├── media/
│   ├── backups/
│   └── .env.production
├── venv/                   # Python virtual environment
│
├── Makefile                # Universal command interface
├── pyproject.toml          # Poe tasks + dependencies
├── validate.sh             # Conformance checker
├── .template-version       # "2.0.0"
│
├── scripts/
│   └── poe_commands.py     # Poe implementations
├── systemd/                # Service unit files
│   ├── {project}-web.service
│   ├── {project}-api.service
│   └── {project}-celery.service
│
└── web/                    # Application code
```

## Port Registry

Each project gets 10 ports (bind to 127.0.0.1 only):

| Project | Range | Web | API | Docs |
|---------|-------|-----|-----|------|
| ayna-comply | 8100-8109 | 8100 | 8101 | 8102 |
| ayna-fly | 8110-8119 | 8110 | 8111 | 8112 |
| aynasite | 8120-8129 | 8120 | 8121 | 8122 |
| uavcrew | 8130-8139 | 8130 | 8131 | 8132 |
| skybookus | 8140-8149 | 8140 | 8141 | 8142 |

## Blue-Green Deployment

```bash
make deploy
```

1. Creates new release directory
2. Git pull / copy code
3. Install dependencies
4. Run migrations
5. Collect static files
6. Switch symlink to new release
7. Reload services
8. Health check (auto-rollback if failed)

```bash
make rollback  # Instant rollback via symlink switch
```

## Version History

- **2.0.0** - Unified standard (Poe + systemd)
  - Replaces Docker-based approach
  - Based on ayna-comply's proven patterns
  - Adds port registry
  - Adds conformance validation

- **1.0.0** - Initial Docker-based release (deprecated)
  - Docker compose deployment
  - Container-based blue-green

## Legacy Docker Support

Docker artifacts (docker/, compose/) preserved in `legacy/` branch for reference.
Projects needing containerization can still use v1.0.0 patterns.
