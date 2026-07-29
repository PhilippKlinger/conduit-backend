# syntax=docker/dockerfile:1

ARG PYTHON_IMAGE=python:3.6-slim

# Build dependencies in a separate stage to keep the runtime image small.
FROM ${PYTHON_IMAGE} AS builder

ENV PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

COPY requirements.txt ./

# Pip 21.3.1 is the last release that supports the legacy Python 3.6 runtime.
RUN python -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir --upgrade "pip==21.3.1" \
    && /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

# The final image receives only the prepared virtual environment and app code.
FROM ${PYTHON_IMAGE} AS runtime

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH="/opt/venv/bin:${PATH}" \
    DJANGO_DEBUG=False \
    GUNICORN_BIND=0.0.0.0:8000 \
    GUNICORN_WORKERS=3

COPY --from=builder /opt/venv /opt/venv

WORKDIR /app
COPY . .

# Collect Django admin assets during the build and normalize the entrypoint
# permissions so the image also works after a Windows checkout.
RUN python manage.py collectstatic --noinput \
    && sed -i 's/\r$//' /app/entrypoint.sh \
    && chmod +x /app/entrypoint.sh \
    && useradd --create-home --uid 10001 appuser \
    && chown -R appuser:appuser /app

# Run the application without root privileges.
USER appuser

EXPOSE 8000

ENTRYPOINT ["/app/entrypoint.sh"]
