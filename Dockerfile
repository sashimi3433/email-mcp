FROM python:3.12-slim AS base

WORKDIR /app

# Install system dependencies for building Python packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Copy project files
COPY pyproject.toml uv.lock ./
COPY src/ ./src/
COPY README.md LICENSE ./

# Install the package
RUN pip install --no-cache-dir .

# Data directory for SQLite DB and encryption key
RUN mkdir -p /app/data
ENV EMAIL_MCP_WEB_HOST=0.0.0.0
ENV EMAIL_MCP_WEB_PORT=5858

# Web UI + REST API
EXPOSE 5858

VOLUME ["/app/data"]

CMD ["email-mcp-ui"]
