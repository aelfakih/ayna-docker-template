#!/bin/bash
#
# Ayna Deployment Standard v2.0 - Conformance Validator
#
# Checks that a project conforms to the Ayna Deployment Standard.
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
echo "Ayna Deployment Standard v2.0 - Conformance Check"
echo "================================================"
echo ""

# =============================================================================
# Required Files
# =============================================================================

echo "Checking required files..."

[ -f "Makefile" ] && log_ok "Makefile exists" || log_error "Makefile missing"
[ -f "pyproject.toml" ] && log_ok "pyproject.toml exists" || log_error "pyproject.toml missing"
[ -f ".template-version" ] && log_ok ".template-version exists" || log_warn ".template-version missing"
[ -f "validate.sh" ] && log_ok "validate.sh exists" || log_error "validate.sh missing"

echo ""

# =============================================================================
# Directory Structure
# =============================================================================

echo "Checking directory structure..."

[ -d "scripts" ] && log_ok "scripts/ directory exists" || log_error "scripts/ directory missing"
[ -d "systemd" ] && log_ok "systemd/ directory exists" || log_warn "systemd/ directory missing (create for production)"
[ -d "web" ] && log_ok "web/ directory exists" || log_warn "web/ directory missing"
[ -d "api" ] && log_ok "api/ directory exists" || log_warn "api/ directory missing"

if [ -d "scripts" ]; then
    [ -f "scripts/poe_commands.py" ] && log_ok "scripts/poe_commands.py exists" || log_error "scripts/poe_commands.py missing"
fi

if [ -d "systemd" ]; then
    ls systemd/*.service >/dev/null 2>&1 && log_ok "systemd service files found" || log_warn "No systemd service files in systemd/"
fi

echo ""

# =============================================================================
# Makefile Targets
# =============================================================================

echo "Checking Makefile targets..."

REQUIRED_TARGETS="run deploy rollback migrate shell logs start stop restart status validate"

for target in $REQUIRED_TARGETS; do
    if grep -q "^${target}:" Makefile 2>/dev/null; then
        log_ok "make $target defined"
    else
        log_error "make $target missing"
    fi
done

echo ""

# =============================================================================
# Poe Tasks
# =============================================================================

echo "Checking Poe tasks in pyproject.toml..."

if [ -f "pyproject.toml" ]; then
    if grep -q '\[tool.poe.tasks' pyproject.toml; then
        log_ok "[tool.poe.tasks] section exists"

        # Check for key Poe tasks
        POE_TASKS="dev deploy rollback"
        for task in $POE_TASKS; do
            if grep -q "tasks.$task\]" pyproject.toml || grep -q "tasks.\"$task\"\]" pyproject.toml; then
                log_ok "poe $task defined"
            else
                log_warn "poe $task not found"
            fi
        done
    else
        log_error "[tool.poe.tasks] section missing in pyproject.toml"
    fi
fi

echo ""

# =============================================================================
# Port Configuration
# =============================================================================

echo "Checking port configuration..."

# Check if ports are defined in Makefile
if grep -q "WEB_PORT" Makefile; then
    WEB_PORT=$(grep "WEB_PORT" Makefile | head -1 | grep -oE '[0-9]+' | head -1)
    if [ -n "$WEB_PORT" ]; then
        log_ok "WEB_PORT defined: $WEB_PORT"

        # Validate port is in acceptable range (8100-8199)
        if [ "$WEB_PORT" -ge 8100 ] && [ "$WEB_PORT" -le 8199 ]; then
            log_ok "WEB_PORT in valid range (8100-8199)"
        else
            log_warn "WEB_PORT $WEB_PORT is outside standard range (8100-8199)"
        fi
    fi
else
    log_warn "WEB_PORT not defined in Makefile"
fi

echo ""

# =============================================================================
# Environment Configuration
# =============================================================================

echo "Checking environment configuration..."

[ -f ".env" ] && log_ok ".env exists" || log_warn ".env missing (copy from .env.example)"
[ -f ".env.example" ] && log_ok ".env.example exists" || log_warn ".env.example missing"

if [ -d "shared" ]; then
    log_ok "shared/ directory exists"
    [ -d "shared/media" ] && log_ok "shared/media/ exists" || log_warn "shared/media/ missing"
    [ -d "shared/backups" ] && log_ok "shared/backups/ exists" || log_warn "shared/backups/ missing"
else
    log_warn "shared/ directory missing (create for production)"
fi

echo ""

# =============================================================================
# Virtual Environment
# =============================================================================

echo "Checking Python environment..."

if [ -d "venv" ]; then
    log_ok "venv/ exists"
    if [ -f "venv/bin/python" ]; then
        PYTHON_VERSION=$(venv/bin/python --version 2>&1)
        log_ok "Python: $PYTHON_VERSION"
    fi
    if [ -f "venv/bin/poe" ]; then
        log_ok "Poe the Poet installed"
    else
        log_warn "Poe the Poet not installed (pip install poethepoet)"
    fi
else
    log_warn "venv/ missing"
fi

echo ""

# =============================================================================
# Docker Cleanup (v2.0 removes Docker)
# =============================================================================

echo "Checking for Docker artifacts (should be removed in v2.0)..."

if [ -d "docker" ]; then
    log_warn "docker/ directory exists (can be removed for v2.0)"
fi

if [ -d "compose" ]; then
    log_warn "compose/ directory exists (can be removed for v2.0)"
fi

if [ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ]; then
    log_warn "docker-compose.yml exists (can be removed for v2.0)"
fi

echo ""

# =============================================================================
# Summary
# =============================================================================

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
    echo "Fix the errors above to conform to the Ayna Deployment Standard v2.0."
    exit 1
fi
