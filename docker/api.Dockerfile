# Ayna Docker Standard - API Dockerfile Template
# Version: 1.0.0
#
# Multi-stage build for Python API services (FastAPI, Django, etc.)

# =============================================================================
# Stage 1: Builder
# =============================================================================

FROM python:3.12-slim as builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY pyproject.toml ./
COPY requirements*.txt ./

# Create virtual environment and install dependencies
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install dependencies (prefer pyproject.toml, fallback to requirements.txt)
RUN pip install --no-cache-dir --upgrade pip && \
    (pip install --no-cache-dir . 2>/dev/null || \
     pip install --no-cache-dir -r requirements.txt 2>/dev/null || \
     echo "No dependencies to install")

# =============================================================================
# Stage 2: Production
# =============================================================================

FROM python:3.12-slim as production

WORKDIR /app

# Install runtime dependencies only
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd --create-home --shell /bin/bash appuser

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy application code
COPY --chown=appuser:appuser . .

# Switch to non-root user
USER appuser

# Health check endpoint
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Default command (override in compose)
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]

# =============================================================================
# Stage 3: Development (optional, for hot reload)
# =============================================================================

FROM python:3.12-slim as development

WORKDIR /app

# Install all dependencies including dev
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install dev dependencies
RUN pip install --no-cache-dir pytest pytest-asyncio ruff

# Mount point for source code (don't copy, mount in compose)
VOLUME /app

EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
