# Ayna Docker Deployment Standard - Makefile Template
# Version: 1.0.0
#
# This Makefile provides a universal interface for all Ayna Docker projects.
# Copy this to your project and customize the variables below.

# =============================================================================
# Project Configuration (customize these)
# =============================================================================

PROJECT_NAME ?= myproject
API_PORT ?= 8000
WEB_PORT ?= 8001
DOCS_PORT ?= 8002

# Compose files
COMPOSE_DEV = compose/dev.yml
COMPOSE_PROD = compose/prod.yml
ENV_FILE = .env

# Colors
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

# =============================================================================
# Required Targets (DO NOT REMOVE)
# =============================================================================

.PHONY: run build prod deploy rollback migrate shell logs stop status validate help

## run: Start development environment with hot reload
run:
	@echo "$(GREEN)[DEV]$(NC) Starting development environment..."
	docker compose -f $(COMPOSE_DEV) --env-file $(ENV_FILE) up

## build: Build all Docker images
build:
	@echo "$(GREEN)[BUILD]$(NC) Building all images..."
	docker compose -f $(COMPOSE_PROD) --env-file $(ENV_FILE) build

## prod: Start production environment
prod:
	@echo "$(GREEN)[PROD]$(NC) Starting production environment..."
	docker compose -f $(COMPOSE_PROD) --env-file $(ENV_FILE) up -d

## deploy: Blue-green deployment with health check
deploy:
	@echo "$(GREEN)[DEPLOY]$(NC) Starting blue-green deployment..."
	@# Tag current image as rollback
	@docker tag $(PROJECT_NAME)-api:latest $(PROJECT_NAME)-api:rollback 2>/dev/null || true
	@# Build new image
	docker compose -f $(COMPOSE_PROD) --env-file $(ENV_FILE) build
	@# Start new container
	docker compose -f $(COMPOSE_PROD) --env-file $(ENV_FILE) up -d
	@# Health check
	@echo "$(YELLOW)[DEPLOY]$(NC) Waiting for health check..."
	@sleep 5
	@if docker compose -f $(COMPOSE_PROD) ps | grep -q "unhealthy"; then \
		echo "$(RED)[DEPLOY]$(NC) Health check failed! Rolling back..."; \
		$(MAKE) rollback; \
		exit 1; \
	fi
	@echo "$(GREEN)[DEPLOY]$(NC) Deployment successful!"

## rollback: Instant rollback to previous version
rollback:
	@echo "$(YELLOW)[ROLLBACK]$(NC) Rolling back to previous version..."
	@docker tag $(PROJECT_NAME)-api:rollback $(PROJECT_NAME)-api:latest 2>/dev/null || \
		(echo "$(RED)[ROLLBACK]$(NC) No rollback image found!" && exit 1)
	docker compose -f $(COMPOSE_PROD) --env-file $(ENV_FILE) up -d --force-recreate
	@echo "$(GREEN)[ROLLBACK]$(NC) Rollback complete!"

## migrate: Run database migrations
migrate:
	@echo "$(GREEN)[MIGRATE]$(NC) Running migrations..."
	docker compose -f $(COMPOSE_PROD) exec api python manage.py migrate --noinput 2>/dev/null || \
	docker compose -f $(COMPOSE_PROD) exec api alembic upgrade head 2>/dev/null || \
	echo "$(YELLOW)[MIGRATE]$(NC) No migration command found"

## shell: Open shell in API container
shell:
	docker compose -f $(COMPOSE_PROD) exec api /bin/bash 2>/dev/null || \
	docker compose -f $(COMPOSE_PROD) exec api /bin/sh

## logs: Stream logs from all services
logs:
	docker compose -f $(COMPOSE_PROD) logs -f

## stop: Stop all services
stop:
	@echo "$(YELLOW)[STOP]$(NC) Stopping all services..."
	docker compose -f $(COMPOSE_PROD) down
	docker compose -f $(COMPOSE_DEV) down 2>/dev/null || true
	@echo "$(GREEN)[STOP]$(NC) All services stopped."

## status: Show service status and health
status:
	@echo "$(GREEN)=== $(PROJECT_NAME) Services ===$(NC)"
	@docker compose -f $(COMPOSE_PROD) ps 2>/dev/null || echo "Production not running"
	@echo ""
	@echo "$(GREEN)=== Health Checks ===$(NC)"
	@curl -sf http://localhost:$(API_PORT)/health > /dev/null 2>&1 && \
		echo "API:  $(GREEN)healthy$(NC)" || echo "API:  $(RED)unhealthy$(NC)"

## validate: Check conformance to Ayna Docker standard
validate:
	@./validate.sh

## update-template: Pull latest template changes
update-template:
	@echo "$(GREEN)[UPDATE]$(NC) Checking for template updates..."
	@./scripts/update-template.sh

# =============================================================================
# Optional Targets (customize as needed)
# =============================================================================

## test: Run tests
test:
	docker compose -f $(COMPOSE_DEV) exec api pytest

## lint: Run linters
lint:
	docker compose -f $(COMPOSE_DEV) exec api ruff check .

## format: Format code
format:
	docker compose -f $(COMPOSE_DEV) exec api ruff format .

## clean: Remove all containers, images, and volumes
clean:
	@echo "$(RED)[CLEAN]$(NC) Removing all project resources..."
	docker compose -f $(COMPOSE_PROD) down -v --rmi local 2>/dev/null || true
	docker compose -f $(COMPOSE_DEV) down -v --rmi local 2>/dev/null || true
	@echo "$(GREEN)[CLEAN]$(NC) Cleanup complete."

# =============================================================================
# Help
# =============================================================================

## help: Show this help message
help:
	@echo "$(GREEN)Ayna Docker Deployment - $(PROJECT_NAME)$(NC)"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## /  /' | column -t -s ':'
