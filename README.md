# Ayna Docker Deployment Template

Standard Docker deployment pattern for all Ayna projects.

## Quick Start

### Create a New Project

```bash
./init.sh myproject ~/repos
cd ~/repos/myproject
```

### Apply to Existing Project

```bash
# Clone template
git clone https://github.com/ayna-ai/ayna-docker-template.git /tmp/template

# Copy required files
cp -r /tmp/template/{Makefile,validate.sh,.env.example} .
cp -r /tmp/template/{docker,compose,caddy,scripts} .

# Track template version
echo "1.0.0" > .template-version

# Customize and run
make validate
```

## Standard Commands

| Command | Description |
|---------|-------------|
| `make run` | Start development environment (hot reload) |
| `make build` | Build all Docker images |
| `make prod` | Start production environment |
| `make deploy` | Blue-green deployment with health check |
| `make rollback` | Instant rollback to previous version |
| `make migrate` | Run database migrations |
| `make shell` | Open shell in API container |
| `make logs` | Stream logs |
| `make stop` | Stop all services |
| `make status` | Show service status |
| `make validate` | Check conformance to standard |

## Directory Structure

```
project/
├── docker/                 # Dockerfiles only
│   ├── api.Dockerfile
│   ├── web.Dockerfile      # Optional: Django/frontend
│   └── docs.Dockerfile     # Optional: Documentation
├── compose/
│   ├── dev.yml            # Development (hot reload)
│   └── prod.yml           # Production (built images)
├── caddy/
│   └── Caddyfile          # Reverse proxy config
├── scripts/
│   ├── entrypoint.sh      # Container startup
│   └── update-template.sh # Pull template updates
├── Makefile               # Universal command interface
├── .env.example           # Template environment file
├── .env                   # Local config (gitignored)
├── validate.sh            # Conformance checker
├── .template-version      # Tracks template version
└── src/                   # Application code
```

## Updating from Template

Projects can pull the latest template changes:

```bash
make update-template
```

This updates:
- `validate.sh`
- `scripts/update-template.sh`
- `scripts/entrypoint.sh`

It will NOT overwrite your customizations to:
- `Makefile`
- `compose/*.yml`
- `docker/*.Dockerfile`
- `.env` or `.env.example`

## Conformance Validation

Run the validator to check your project follows the standard:

```bash
./validate.sh
```

Checks include:
- Required files exist
- Makefile has all required targets
- Dockerfiles follow best practices
- Compose files have health checks
- Environment variables documented

## Blue-Green Deployment

The `make deploy` command implements zero-downtime deployment:

1. Tags current image as `:rollback`
2. Builds new image
3. Starts new container
4. Runs health check (5 second timeout)
5. If healthy: deployment complete
6. If unhealthy: automatic rollback

Manual rollback:
```bash
make rollback
```

## Version History

- **1.0.0** - Initial release
  - Standard directory structure
  - Makefile with required targets
  - Blue-green deployment support
  - Conformance validation
  - Template self-update capability
