# Ayna Port Registry

Standard port assignments for all Ayna projects to prevent conflicts when running on the same server.

## Port Ranges

Each project is allocated 10 ports for flexibility.

| Project | Range | Web | API | Docs | Reserved |
|---------|-------|-----|-----|------|----------|
| ayna | 8100-8109 | 8100 | 8101 | 8102 | 8103-8109 |
| ayna-fly | 8110-8119 | 8110 | 8111 | 8112 | 8113-8119 |
| aynasite | 8120-8129 | 8120 | 8121 | 8122 | 8123-8129 |
| uavcrew | 8130-8139 | 8130 | 8131 | 8132 | 8133-8139 |
| skybookus | 8140-8149 | 8140 | 8141 | 8142 | 8143-8149 |
| *(future)* | 8150-8199 | - | - | - | - |

## Port Convention

Within each project's 10-port range:

| Offset | Purpose |
|--------|---------|
| +0 | Web/Frontend (Django, React, etc.) |
| +1 | API (FastAPI, REST API) |
| +2 | Documentation (Sphinx, MkDocs) |
| +3 | WebSocket server (if needed) |
| +4 | Admin/Internal tools |
| +5-9 | Reserved for future use |

## Usage in Compose Files

```yaml
# Example: uavcrew (range 8130-8139)
services:
  web:
    ports:
      - "127.0.0.1:8130:8000"  # Web
  api:
    ports:
      - "127.0.0.1:8131:8000"  # API
  docs:
    ports:
      - "127.0.0.1:8132:80"    # Docs
```

## Reverse Proxy (Caddy)

Caddy routes external traffic by subdomain:

```
www.uavcrew.ai   -> localhost:8130
api.uavcrew.ai   -> localhost:8131
docs.uavcrew.ai  -> localhost:8132
```

## Adding New Projects

1. Claim the next available range (8150+)
2. Update this registry
3. Configure your compose files with the assigned ports

## Notes

- All services bind to `127.0.0.1` only (localhost)
- External access is through Caddy reverse proxy on ports 80/443
- Internal Docker communication uses container names, not ports
- Workers (Celery, etc.) don't need exposed ports
