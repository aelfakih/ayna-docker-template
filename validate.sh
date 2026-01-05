#!/bin/bash
#
# Ayna Deployment Standard v2.1 - Conformance Validator
#
# Checks that a project conforms to the Ayna Deployment Standard.
# Run from project root: ./validate.sh or: poe validate
#
# v2.1: Removed Makefile requirement, poe commands only

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
echo "Ayna Deployment Standard v2.1 - Conformance Check"
echo "================================================"
echo ""

# =============================================================================
# Required Files
# =============================================================================

echo "Checking required files..."

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
[ -d "releases" ] && log_ok "releases/ directory exists" || log_warn "releases/ directory missing"
[ -d "shared" ] && log_ok "shared/ directory exists" || log_warn "shared/ directory missing"

if [ -d "scripts" ]; then
    [ -f "scripts/poe_commands.py" ] && log_ok "scripts/poe_commands.py exists" || log_error "scripts/poe_commands.py missing"
fi

if [ -d "systemd" ]; then
    ls systemd/*.service >/dev/null 2>&1 && log_ok "systemd service files found" || log_warn "No systemd service files in systemd/"
fi

echo ""

# =============================================================================
# Poe Tasks (Required)
# =============================================================================

echo "Checking Poe tasks in pyproject.toml..."

if [ -f "pyproject.toml" ]; then
    if grep -q '\[tool.poe.tasks' pyproject.toml; then
        log_ok "[tool.poe.tasks] section exists"

        # Required Poe tasks
        REQUIRED_TASKS="dev deploy rollback migrate services:status services:start services:stop services:restart logs"
        for task in $REQUIRED_TASKS; do
            # Handle both regular and quoted task names
            if grep -qE "tasks\.$task\]|tasks\.\"$task\"\]" pyproject.toml; then
                log_ok "poe $task defined"
            else
                log_error "poe $task missing"
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

# Check if ports are defined in poe_commands.py
if [ -f "scripts/poe_commands.py" ]; then
    if grep -q "PORTS" scripts/poe_commands.py; then
        WEB_PORT=$(grep -A5 "PORTS = {" scripts/poe_commands.py | grep "web" | grep -oE '[0-9]+' | head -1)
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
        log_warn "PORTS not defined in scripts/poe_commands.py"
    fi
fi

echo ""

# =============================================================================
# Environment Configuration
# =============================================================================

echo "Checking environment configuration..."

[ -f ".env" ] || [ -L ".env" ] && log_ok ".env exists" || log_warn ".env missing (create symlink to shared/.env.*)"
[ -f ".env.example" ] && log_ok ".env.example exists" || log_warn ".env.example missing"

if [ -d "shared" ]; then
    [ -d "shared/media" ] && log_ok "shared/media/ exists" || log_warn "shared/media/ missing"
    [ -d "shared/backups" ] && log_ok "shared/backups/ exists" || log_warn "shared/backups/ missing"
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
        log_error "Poe the Poet not installed (pip install poethepoet)"
    fi
else
    log_warn "venv/ missing"
fi

echo ""

# =============================================================================
# Docker Cleanup (v2.0+ removes Docker)
# =============================================================================

echo "Checking for Docker artifacts (should be removed in v2.0+)..."

DOCKER_FOUND=0
if [ -d "docker" ]; then
    log_warn "docker/ directory exists (can be removed)"
    DOCKER_FOUND=1
fi

if [ -d "compose" ]; then
    log_warn "compose/ directory exists (can be removed)"
    DOCKER_FOUND=1
fi

if [ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ]; then
    log_warn "docker-compose.yml exists (can be removed)"
    DOCKER_FOUND=1
fi

if [ -f "Makefile" ]; then
    log_warn "Makefile exists (can be removed in v2.1+, use poe commands)"
fi

[ $DOCKER_FOUND -eq 0 ] && log_ok "No Docker artifacts found"

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
    echo "Fix the errors above to conform to the Ayna Deployment Standard v2.1."
    exit 1
fi
