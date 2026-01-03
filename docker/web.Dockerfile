# Ayna Docker Standard - Web Dockerfile Template
# Version: 1.0.0
#
# For Django applications with static files

# =============================================================================
# Stage 1: Builder
# =============================================================================

FROM python:3.12-slim as builder

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements*.txt ./
COPY pyproject.toml ./

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

RUN pip install --no-cache-dir --upgrade pip && \
    (pip install --no-cache-dir . 2>/dev/null || \
     pip install --no-cache-dir -r requirements.txt 2>/dev/null || \
     echo "No dependencies to install")

# =============================================================================
# Stage 2: Production
# =============================================================================

FROM python:3.12-slim as production

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd --create-home --shell /bin/bash appuser

# Copy virtual environment
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy application
COPY --chown=appuser:appuser . .

# Collect static files (if Django)
RUN python manage.py collectstatic --noinput 2>/dev/null || true

# Create directories for logs
RUN mkdir -p /var/log/app && chown appuser:appuser /var/log/app

USER appuser

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8000/health/ || exit 1

EXPOSE 8000
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "4", "config.wsgi:application"]
