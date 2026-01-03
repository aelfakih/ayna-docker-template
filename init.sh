#!/bin/bash
#
# Ayna Docker Standard - Project Initializer
# Version: 1.0.0
#
# Creates a new project from the Ayna Docker template.
#
# Usage:
#   ./init.sh <project-name> [target-directory]
#
# Example:
#   ./init.sh myapi ~/repos/my-api
#   ./init.sh skybook  # Creates ./skybook

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INIT]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[INIT]${NC} $1"; }
log_error() { echo -e "${RED}[INIT]${NC} $1"; }

# =============================================================================
# Parse arguments
# =============================================================================

if [ -z "$1" ]; then
    echo "Usage: ./init.sh <project-name> [target-directory]"
    echo ""
    echo "Creates a new project from the Ayna Docker template."
    echo ""
    echo "Examples:"
    echo "  ./init.sh myapi              # Creates ./myapi"
    echo "  ./init.sh myapi ~/repos      # Creates ~/repos/myapi"
    exit 1
fi

PROJECT_NAME="$1"
TARGET_DIR="${2:-.}/$PROJECT_NAME"

# Validate project name (lowercase, alphanumeric, hyphens)
if ! echo "$PROJECT_NAME" | grep -qE '^[a-z][a-z0-9-]*$'; then
    log_error "Invalid project name: $PROJECT_NAME"
    log_info "Use lowercase letters, numbers, and hyphens (e.g., my-api)"
    exit 1
fi

# Check if target exists
if [ -d "$TARGET_DIR" ]; then
    log_error "Directory already exists: $TARGET_DIR"
    exit 1
fi

# =============================================================================
# Get template directory
# =============================================================================

TEMPLATE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION=$(cat "$TEMPLATE_DIR/VERSION")

log_info "Creating project: $PROJECT_NAME"
log_info "Template version: $VERSION"
log_info "Target: $TARGET_DIR"
echo ""

# =============================================================================
# Create project structure
# =============================================================================

mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

# Copy template files
log_info "Copying template files..."

mkdir -p docker compose caddy scripts src

# Copy Dockerfiles
cp "$TEMPLATE_DIR/docker/"*.Dockerfile docker/ 2>/dev/null || true

# Copy compose files
cp "$TEMPLATE_DIR/compose/"*.yml compose/

# Copy Caddy config
cp "$TEMPLATE_DIR/caddy/Caddyfile" caddy/

# Copy scripts
cp "$TEMPLATE_DIR/scripts/"*.sh scripts/

# Copy root files
cp "$TEMPLATE_DIR/Makefile" .
cp "$TEMPLATE_DIR/validate.sh" .
cp "$TEMPLATE_DIR/.env.example" .

# Create version tracking file
echo "$VERSION" > .template-version

# =============================================================================
# Customize for project
# =============================================================================

log_info "Customizing for $PROJECT_NAME..."

# Update Makefile
sed -i "s/PROJECT_NAME ?= myproject/PROJECT_NAME ?= $PROJECT_NAME/" Makefile

# Update .env.example
sed -i "s/PROJECT_NAME=myproject/PROJECT_NAME=$PROJECT_NAME/" .env.example

# Create initial .env from example
cp .env.example .env

# Create placeholder source directory
cat > src/README.md << EOF
# $PROJECT_NAME

Source code goes here.

## Structure

Recommended layout for Python projects:

\`\`\`
src/
├── main.py          # Application entry point
├── config.py        # Configuration
├── models/          # Data models
├── routes/          # API routes
├── services/        # Business logic
└── utils/           # Utilities
\`\`\`
EOF

# =============================================================================
# Initialize git repository
# =============================================================================

log_info "Initializing git repository..."

cat > .gitignore << 'EOF'
# Environment
.env
.env.local
.env.production
!.env.example

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
venv/
.venv/
*.egg-info/
dist/
build/

# IDE
.idea/
.vscode/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Docker
*.log

# Testing
.coverage
htmlcov/
.pytest_cache/

# Misc
*.bak
*.tmp
EOF

git init
git add .
git commit -m "Initial commit from ayna-docker-template v$VERSION"

# =============================================================================
# Make scripts executable
# =============================================================================

chmod +x validate.sh scripts/*.sh

# =============================================================================
# Summary
# =============================================================================

echo ""
log_info "================================================"
log_info "Project created successfully!"
log_info "================================================"
echo ""
log_info "Next steps:"
echo ""
echo "  1. cd $TARGET_DIR"
echo "  2. Edit .env with your configuration"
echo "  3. Add your application code to src/"
echo "  4. Update docker/api.Dockerfile for your app"
echo "  5. Run: make run"
echo ""
log_info "Available commands:"
echo ""
echo "  make run       - Start development environment"
echo "  make build     - Build Docker images"
echo "  make prod      - Start production environment"
echo "  make deploy    - Blue-green deployment"
echo "  make validate  - Check conformance to standard"
echo "  make help      - Show all commands"
echo ""
