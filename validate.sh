#!/bin/bash
#
# Ayna Docker Standard - Conformance Validator
# Version: 1.0.0
#
# Checks that a project conforms to the Ayna Docker deployment standard.
# Run from project root: ./validate.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

log_ok() { echo -e "${GREEN}✓${NC} $1"; }
log_warn() { echo -e "${YELLOW}⚠${NC} $1"; WARNINGS=$((WARNINGS+1)); }
log_error() { echo -e "${RED}✗${NC} $1"; ERRORS=$((ERRORS+1)); }
log_info() { echo -e "  $1"; }

echo "================================================"
echo "Ayna Docker Standard - Conformance Check"
echo "================================================"
echo ""

# Check required files
echo "Checking required files..."

[ -f "Makefile" ] && log_ok "Makefile exists" || log_error "Makefile missing"
[ -f ".env.example" ] && log_ok ".env.example exists" || log_error ".env.example missing"
[ -f ".template-version" ] && log_ok ".template-version exists" || log_warn ".template-version missing (run update-template)"
[ -f "validate.sh" ] && log_ok "validate.sh exists" || log_error "validate.sh missing"

echo ""

# Check directory structure
echo "Checking directory structure..."

[ -d "docker" ] && log_ok "docker/ directory exists" || log_error "docker/ directory missing"
[ -d "compose" ] && log_ok "compose/ directory exists" || log_error "compose/ directory missing"

if [ -d "docker" ]; then
    ls docker/*.Dockerfile >/dev/null 2>&1 && log_ok "Dockerfile(s) found in docker/" || log_error "No Dockerfiles in docker/"
fi

if [ -d "compose" ]; then
    [ -f "compose/dev.yml" ] && log_ok "compose/dev.yml exists" || log_warn "compose/dev.yml missing"
    [ -f "compose/prod.yml" ] && log_ok "compose/prod.yml exists" || log_error "compose/prod.yml missing"
fi

echo ""

# Check Makefile targets
echo "Checking Makefile targets..."

REQUIRED_TARGETS="run build prod deploy rollback migrate shell logs stop status validate"

for target in $REQUIRED_TARGETS; do
    if grep -q "^${target}:" Makefile 2>/dev/null; then
        log_ok "make $target defined"
    else
        log_error "make $target missing"
    fi
done

echo ""

# Check Dockerfile standards
echo "Checking Dockerfile standards..."

for dockerfile in docker/*.Dockerfile; do
    [ -f "$dockerfile" ] || continue

    name=$(basename "$dockerfile")

    # Check for python base image
    if grep -q "FROM python:" "$dockerfile"; then
        if grep -q "python:3.12" "$dockerfile"; then
            log_ok "$name uses Python 3.12"
        else
            log_warn "$name should use python:3.12-slim"
        fi
    fi

    # Check for WORKDIR
    if grep -q "WORKDIR /app" "$dockerfile"; then
        log_ok "$name has WORKDIR /app"
    else
        log_warn "$name should use WORKDIR /app"
    fi

    # Check for non-root user (production)
    if grep -q "USER" "$dockerfile"; then
        log_ok "$name runs as non-root user"
    else
        log_warn "$name should run as non-root user in production"
    fi
done

echo ""

# Check environment variables
echo "Checking .env.example..."

if [ -f ".env.example" ]; then
    REQUIRED_VARS="PROJECT_NAME DATABASE_URL REDIS_URL SECRET_KEY"

    for var in $REQUIRED_VARS; do
        if grep -q "^${var}=" .env.example || grep -q "^#.*${var}=" .env.example; then
            log_ok "$var documented"
        else
            log_warn "$var not documented in .env.example"
        fi
    done
fi

echo ""

# Check compose files for health checks
echo "Checking compose file standards..."

for compose in compose/*.yml; do
    [ -f "$compose" ] || continue

    name=$(basename "$compose")

    if grep -q "healthcheck:" "$compose"; then
        log_ok "$name has health checks"
    else
        log_warn "$name should include health checks"
    fi

    if grep -q "env_file:" "$compose" || grep -q '${' "$compose"; then
        log_ok "$name uses environment variables"
    else
        log_warn "$name should use .env file"
    fi
done

echo ""

# Summary
echo "================================================"
echo "Summary"
echo "================================================"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}All checks passed!${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}$WARNINGS warning(s), 0 errors${NC}"
    exit 0
else
    echo -e "${RED}$ERRORS error(s), $WARNINGS warning(s)${NC}"
    echo ""
    echo "Fix the errors above to conform to the Ayna Docker standard."
    exit 1
fi
