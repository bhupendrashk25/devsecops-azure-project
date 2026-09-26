# =========================================================
# Stage 1 - Builder
# =========================================================
FROM python:3.11-slim-trixie AS builder

WORKDIR /build

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

COPY requirements.txt .

RUN python -m venv /opt/venv

# Upgrade packaging tools only for build
RUN /opt/venv/bin/pip install --no-cache-dir \
    --upgrade \
    pip \
    setuptools \
    wheel

# Install application dependencies
RUN /opt/venv/bin/pip install --no-cache-dir \
    -r requirements.txt


# =========================================================
# Stage 2 - Runtime
# =========================================================
# =========================================================
# Stage 2 - Runtime
# =========================================================
FROM python:3.11-slim-trixie

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH"

# Update OS packages
RUN apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN groupadd --gid 1000 appuser && \
    useradd --uid 1000 \
             --gid 1000 \
             --create-home \
             --shell /usr/sbin/nologin \
             appuser

# Copy Python environment
COPY --from=builder /opt/venv /opt/venv

# Copy application
COPY app ./app

# =========================================================
# Remove packaging tools from BOTH runtime locations
# =========================================================

# Remove packaging tools from virtual environment
RUN /opt/venv/bin/pip uninstall -y \
    pip \
    setuptools \
    wheel || true

# Remove packaging tools bundled in the Python base image
RUN rm -rf \
    /usr/local/lib/python3.11/site-packages/setuptools \
    /usr/local/lib/python3.11/site-packages/setuptools-*.dist-info \
    /usr/local/lib/python3.11/site-packages/wheel \
    /usr/local/lib/python3.11/site-packages/wheel-*.dist-info \
    /usr/local/lib/python3.11/site-packages/pip \
    /usr/local/lib/python3.11/site-packages/pip-*.dist-info

# Verify vulnerable vendored metadata is gone
RUN ! find /usr/local/lib/python3.11/site-packages \
    -path '*setuptools/_vendor/jaraco.context*' \
    -o -path '*setuptools/_vendor/wheel*' | grep -q .

# Permissions
RUN chown -R appuser:appuser /app /opt/venv

USER appuser

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]
