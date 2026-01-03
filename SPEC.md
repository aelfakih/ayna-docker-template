# Ayna Docker Deployment Standard

Version: 1.0.0

## Overview

This specification defines the standard Docker deployment pattern for all Ayna projects.
All Python-based services (Django, FastAPI, Celery, etc.) MUST follow this pattern.

## Directory Structure

```
project/
├── docker/                 # Dockerfiles only
│   ├── api.Dockerfile
│   ├── web.Dockerfile      # Optional: Django/frontend
│   ├── worker.Dockerfile   # Optional: Celery worker
│   └── docs.Dockerfile     # Optional: Documentation
├── compose/
│   ├── dev.yml            # Development (hot reload)
│   └── prod.yml           # Production (built images)
├── caddy/
│   └── Caddyfile          # Reverse proxy config
├── scripts/
│   └── entrypoint.sh      # Optional: startup scripts
├── Makefile               # Universal command interface
├── .env.example           # Template environment file
├── .env                   # Local config (gitignored)
├── validate.sh            # Conformance checker
├── .template-version      # Tracks template version
└── src/                   # Application code
```

## Required Makefile Targets

| Target | Description |
|--------|-------------|
| `make run` | Start development environment |
| `make build` | Build all images |
| `make prod` | Start production environment |
| `make deploy` | Blue-green deploy with health check |
| `make rollback` | Instant rollback to previous version |
| `make migrate` | Run database migrations |
| `make shell` | Open shell in API container |
| `make logs` | Stream logs |
| `make stop` | Stop all services |
| `make status` | Show service status |
| `make validate` | Check conformance to standard |

## Dockerfile Standards

1. Use official Python base image: `python:3.12-slim`
2. Set `WORKDIR /app`
3. Install system dependencies first (caching)
4. Copy requirements/pyproject.toml before code (caching)
5. Use multi-stage builds for smaller images
6. Run as non-root user in production
7. Include health check endpoint

## Compose Standards

1. Use `.env` file for all configuration
2. Dev mode: mount source code for hot reload
3. Prod mode: use built images, no mounts
4. Include health checks for all services
5. Use named volumes for persistence
6. Services expose ports, Caddy handles external access
7. Use explicit `container_name: ${PROJECT_NAME}-<service>`

## Container Naming

All containers MUST be named with the project prefix:

```yaml
container_name: ${PROJECT_NAME}-api
container_name: ${PROJECT_NAME}-web
container_name: ${PROJECT_NAME}-docs
container_name: ${PROJECT_NAME}-redis
container_name: ${PROJECT_NAME}-celery
```

This ensures containers are identifiable when multiple projects run on the same server.

## Port Registry

See `PORT_REGISTRY.md` for assigned port ranges. Each project gets 10 ports:

| Project | Range |
|---------|-------|
| ayna | 8100-8109 |
| ayna-fly | 8110-8119 |
| aynasite | 8120-8129 |
| uavcrew | 8130-8139 |
| skybookus | 8140-8149 |

## Environment Variables

Required in `.env`:
- `PROJECT_NAME` - Project identifier
- `API_DOMAIN` - API domain (e.g., api.uavcrew.ai)
- `DATABASE_URL` - PostgreSQL connection string
- `REDIS_URL` - Redis connection string
- `SECRET_KEY` - Application secret

## Blue-Green Deployment

1. Build new image with version tag
2. Tag current image as `:rollback`
3. Start new container
4. Health check (5 second timeout)
5. If healthy: deployment complete
6. If unhealthy: automatic rollback

## Versioning

Projects track their template version in `.template-version`.
Run `make update-template` to pull latest template changes.

## AI Agent Instructions

When working on Ayna projects:
1. Check for `.template-version` file
2. Run `./validate.sh` before making deployment changes
3. Follow this spec exactly - DO NOT deviate
4. If changes to the pattern are needed, update the template repo first
