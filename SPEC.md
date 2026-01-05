# Ayna Deployment Standard

Version: 2.0.0

## Overview

This specification defines the standard deployment pattern for all Ayna Python projects.
All Python-based services (Django, FastAPI, Celery, etc.) MUST follow this pattern.

**See [UNIFIED_STANDARD.md](UNIFIED_STANDARD.md) for the complete specification.**

## Summary

| Aspect | Implementation |
|--------|----------------|
| Command Interface | Makefile |
| Task Orchestration | Poe the Poet |
| Process Management | systemd |
| Python Environment | venv or uv |
| Deployment Strategy | Symlink-based blue-green |
| Rollback | Instant symlink switch |

## Required Makefile Targets

| Target | Description |
|--------|-------------|
| `make run` | Start development environment |
| `make deploy` | Blue-green deploy with health check |
| `make rollback` | Instant rollback to previous version |
| `make migrate` | Run database migrations |
| `make shell` | Application shell |
| `make start` | Start all services |
| `make stop` | Stop all services |
| `make restart` | Restart services |
| `make status` | Show service status |
| `make logs` | Stream logs |
| `make validate` | Check conformance to standard |

## Port Registry

| Project | Range | Web | API | Docs |
|---------|-------|-----|-----|------|
| ayna-comply | 8100-8109 | 8100 | 8101 | 8102 |
| ayna-fly | 8110-8119 | 8110 | 8111 | 8112 |
| aynasite | 8120-8129 | 8120 | 8121 | 8122 |
| uavcrew | 8130-8139 | 8130 | 8131 | 8132 |
| skybookus | 8140-8149 | 8140 | 8141 | 8142 |

## AI Agent Instructions

When working on Ayna projects:

1. Check for `.template-version` file
2. Run `./validate.sh` before making deployment changes
3. Follow this spec exactly - DO NOT deviate
4. Use `make` commands, not direct `poe` or `systemctl` calls
5. If changes to the pattern are needed, update the template repo first
