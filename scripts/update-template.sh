#!/bin/bash
#
# Ayna Docker Standard - Template Update Script
# Version: 1.0.0
#
# Pulls latest changes from the template repository and applies them to the project.
# Only updates template files, never overwrites project-specific configuration.

set -e

# Template repository
TEMPLATE_REPO="https://github.com/aelfakih/ayna-docker-template.git"
TEMPLATE_BRANCH="main"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[UPDATE]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[UPDATE]${NC} $1"; }
log_error() { echo -e "${RED}[UPDATE]${NC} $1"; }

# Get project root (one level up from scripts/)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# =============================================================================
# Check current version
# =============================================================================

CURRENT_VERSION="0.0.0"
if [ -f ".template-version" ]; then
    CURRENT_VERSION=$(cat .template-version)
fi

log_info "Current template version: $CURRENT_VERSION"

# =============================================================================
# Fetch latest template
# =============================================================================

TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

log_info "Fetching latest template..."
git clone --depth 1 --branch "$TEMPLATE_BRANCH" "$TEMPLATE_REPO" "$TEMP_DIR" 2>/dev/null || {
    log_error "Failed to fetch template repository"
    log_info "Make sure you have access to: $TEMPLATE_REPO"
    exit 1
}

LATEST_VERSION=$(cat "$TEMP_DIR/VERSION")
log_info "Latest template version: $LATEST_VERSION"

# =============================================================================
# Compare versions
# =============================================================================

if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
    log_info "Already up to date!"
    exit 0
fi

log_info "Updating from $CURRENT_VERSION to $LATEST_VERSION..."

# =============================================================================
# Update template files (never overwrite project config)
# =============================================================================

# Files that are always updated from template
TEMPLATE_FILES=(
    "validate.sh"
    "scripts/update-template.sh"
    "scripts/entrypoint.sh"
)

# Files that are only created if missing
OPTIONAL_FILES=(
    "Makefile"
    ".env.example"
    "caddy/Caddyfile"
)

# Update core template files
for file in "${TEMPLATE_FILES[@]}"; do
    if [ -f "$TEMP_DIR/$file" ]; then
        mkdir -p "$(dirname "$file")"
        cp "$TEMP_DIR/$file" "$file"
        log_info "Updated: $file"
    fi
done

# Create optional files only if missing
for file in "${OPTIONAL_FILES[@]}"; do
    if [ ! -f "$file" ] && [ -f "$TEMP_DIR/$file" ]; then
        mkdir -p "$(dirname "$file")"
        cp "$TEMP_DIR/$file" "$file"
        log_info "Created: $file"
    fi
done

# =============================================================================
# Update version file
# =============================================================================

echo "$LATEST_VERSION" > .template-version
log_info "Updated .template-version to $LATEST_VERSION"

# =============================================================================
# Show changelog if available
# =============================================================================

if [ -f "$TEMP_DIR/CHANGELOG.md" ]; then
    echo ""
    log_info "=== Recent Changes ==="
    head -50 "$TEMP_DIR/CHANGELOG.md"
fi

# =============================================================================
# Run validation
# =============================================================================

echo ""
log_info "Running validation..."
./validate.sh || log_warn "Some validation checks failed"

echo ""
log_info "Template update complete!"
log_info "Review the changes and commit when ready."
