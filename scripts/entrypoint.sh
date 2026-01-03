#!/bin/bash
#
# Ayna Docker Standard - Entrypoint Script Template
# Version: 1.0.0
#
# Common entrypoint for Python services
# Handles migrations, static files, and startup

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[ENTRYPOINT]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[ENTRYPOINT]${NC} $1"; }

# =============================================================================
# Wait for dependencies
# =============================================================================

wait_for_service() {
    local host=$1
    local port=$2
    local retries=${3:-30}

    log_info "Waiting for $host:$port..."

    for i in $(seq 1 $retries); do
        if nc -z "$host" "$port" 2>/dev/null; then
            log_info "$host:$port is ready!"
            return 0
        fi
        sleep 1
    done

    log_warn "$host:$port not available after $retries seconds"
    return 1
}

# Wait for PostgreSQL if configured
if [ -n "$DATABASE_URL" ] && echo "$DATABASE_URL" | grep -q "postgresql"; then
    DB_HOST=$(echo "$DATABASE_URL" | sed -n 's/.*@\([^:\/]*\).*/\1/p')
    DB_PORT=$(echo "$DATABASE_URL" | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')
    DB_PORT=${DB_PORT:-5432}
    wait_for_service "$DB_HOST" "$DB_PORT" || true
fi

# Wait for Redis if configured
if [ -n "$REDIS_URL" ]; then
    REDIS_HOST=$(echo "$REDIS_URL" | sed -n 's/.*\/\/\([^:]*\).*/\1/p')
    REDIS_PORT=$(echo "$REDIS_URL" | sed -n 's/.*:\([0-9]*\).*/\1/p')
    REDIS_PORT=${REDIS_PORT:-6379}
    wait_for_service "$REDIS_HOST" "$REDIS_PORT" || true
fi

# =============================================================================
# Django-specific setup
# =============================================================================

if [ -f "manage.py" ]; then
    log_info "Django project detected"

    # Run migrations if not explicitly disabled
    if [ "${SKIP_MIGRATIONS:-false}" != "true" ]; then
        log_info "Running migrations..."
        python manage.py migrate --noinput || log_warn "Migrations failed"
    fi

    # Collect static files in production
    if [ "${DEBUG:-true}" = "false" ]; then
        log_info "Collecting static files..."
        python manage.py collectstatic --noinput || log_warn "collectstatic failed"
    fi
fi

# =============================================================================
# FastAPI/Alembic setup
# =============================================================================

if [ -f "alembic.ini" ]; then
    log_info "Alembic detected"

    if [ "${SKIP_MIGRATIONS:-false}" != "true" ]; then
        log_info "Running Alembic migrations..."
        alembic upgrade head || log_warn "Alembic migrations failed"
    fi
fi

# =============================================================================
# Start application
# =============================================================================

log_info "Starting application: $*"
exec "$@"
