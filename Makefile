# Ayna Deployment Standard v2.1 - Makefile Template
#
# This Makefile wraps Poe tasks for a universal interface.
# Copy to your project and customize the variables below.

# =============================================================================
# Project Configuration (customize these)
# =============================================================================

PROJECT_NAME ?= myproject
PROJECT_ROOT ?= /opt/ayna/$(PROJECT_NAME)
WEB_PORT ?= 8100
API_PORT ?= 8101
DOCS_PORT ?= 8102

# Paths
VENV := $(PROJECT_ROOT)/venv
POE := $(VENV)/bin/poe
PYTHON := $(VENV)/bin/python

# Environment (default: dev for safety)
ENV ?= dev

# Colors
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

# =============================================================================
# Required Targets
# =============================================================================

.PHONY: run deploy rollback migrate shell logs start stop restart status validate help

## run: Start development server
run:
	@$(POE) dev

## run-web: Start web server only
run-web:
	@$(POE) dev:web

## run-api: Start API server only
run-api:
	@$(POE) dev:api

# =============================================================================
# Deployment (Blue-Green)
# =============================================================================

## deploy: Blue-green deployment (use ENV=dev|staging|production)
deploy:
	@$(POE) deploy $(ENV)

## rollback: Instant rollback to previous release
rollback:
	@$(POE) rollback

# =============================================================================
# Services (systemd)
# =============================================================================

## start: Start all services
start:
	@$(POE) services:start

## stop: Stop all services
stop:
	@$(POE) services:stop

## restart: Restart all services
restart:
	@$(POE) services:restart

## reload: Gracefully reload all services
reload:
	@$(POE) services:reload

## status: Show service status and health
status:
	@$(POE) services:status

## logs: Stream logs from all services
logs:
	@$(POE) logs

# =============================================================================
# Database
# =============================================================================

## migrate: Run database migrations
migrate:
	@$(POE) migrate

## makemigrations: Create new migrations
makemigrations:
	@$(POE) makemigrations

## shell: Open application shell
shell:
	@$(POE) shell

## dbshell: Open database shell
dbshell:
	@$(POE) dbshell

# =============================================================================
# Static Files
# =============================================================================

## collectstatic: Collect static files
collectstatic:
	@$(POE) collectstatic

# =============================================================================
# Testing & Quality
# =============================================================================

## test: Run test suite
test:
	@$(POE) test

## test-cov: Run tests with coverage
test-cov:
	@$(POE) test:cov

## lint: Run linters
lint:
	@$(POE) lint

## lint-fix: Fix lint issues
lint-fix:
	@$(POE) lint:fix

## format: Format code
format:
	@$(POE) format

## typecheck: Run type checking
typecheck:
	@$(POE) typecheck

## quality: Run all quality checks
quality:
	@$(POE) quality

# =============================================================================
# Environment
# =============================================================================

## env-setup: Setup environment (dev, staging, production)
env-setup:
	@$(POE) env:setup $(ENV)

## env-check: Verify environment setup
env-check:
	@$(POE) env:check

# =============================================================================
# Validation
# =============================================================================

## validate: Check conformance to Ayna Deployment Standard
validate:
	@./validate.sh

# =============================================================================
# Systemd Installation
# =============================================================================

## install-services: Install systemd service files
install-services:
	@echo "$(GREEN)[INSTALL]$(NC) Installing systemd services..."
	sudo cp systemd/*.service /etc/systemd/system/
	sudo systemctl daemon-reload
	@echo "$(GREEN)[INSTALL]$(NC) Services installed. Enable with:"
	@echo "  sudo systemctl enable $(PROJECT_NAME)-web $(PROJECT_NAME)-api $(PROJECT_NAME)-celery $(PROJECT_NAME)-beat"

# =============================================================================
# Help
# =============================================================================

## help: Show this help message
help:
	@echo "$(GREEN)$(PROJECT_NAME) - Ayna Deployment Standard v2.1$(NC)"
	@echo ""
	@echo "Development:"
	@echo "  make run              Start development server"
	@echo "  make run-web          Start web only"
	@echo "  make run-api          Start API only"
	@echo ""
	@echo "Deployment:"
	@echo "  make deploy              Deploy (default: ENV=dev)"
	@echo "  make deploy ENV=dev      Deploy to development"
	@echo "  make deploy ENV=staging  Deploy to staging"
	@echo "  make deploy ENV=production  Deploy to production"
	@echo "  make rollback            Instant rollback"
	@echo ""
	@echo "Services:"
	@echo "  make start        Start all services"
	@echo "  make stop         Stop all services"
	@echo "  make restart      Restart all services"
	@echo "  make status       Show service status"
	@echo "  make logs         Stream logs"
	@echo ""
	@echo "Database:"
	@echo "  make migrate      Run migrations"
	@echo "  make shell        Application shell"
	@echo ""
	@echo "Testing:"
	@echo "  make test         Run tests"
	@echo "  make lint         Run linters"
	@echo "  make quality      Run all quality checks"
	@echo ""
	@echo "Maintenance:"
	@echo "  make validate     Check template conformance"
	@echo "  make install-services  Install systemd units"
