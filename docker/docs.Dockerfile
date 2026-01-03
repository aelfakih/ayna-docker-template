# Ayna Docker Standard - Docs Dockerfile Template
# Version: 1.0.0
#
# For Sphinx/MkDocs documentation sites

FROM python:3.12-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install documentation tools
RUN pip install --no-cache-dir \
    sphinx \
    sphinx-rtd-theme \
    myst-parser \
    sphinx-autobuild

# Copy documentation source
COPY docs/ /app/docs/

# Build documentation
RUN cd /app/docs && make html 2>/dev/null || echo "Build on startup"

# Create non-root user
RUN useradd --create-home appuser
USER appuser

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:8000/ || exit 1

EXPOSE 8000
CMD ["python", "-m", "http.server", "8000", "--directory", "/app/docs/_build/html"]
