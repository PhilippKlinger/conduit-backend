ARG PYTHON_IMAGE=python:3.6-slim

# separate build stage so pip and build files stay out of the runtime image
FROM ${PYTHON_IMAGE} AS builder

WORKDIR /app

COPY requirements.txt ./

# Pip 21.3.1 is the last release that supports the legacy Python 3.6 runtime.
RUN python -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir --upgrade "pip==21.3.1" \
    && /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

FROM ${PYTHON_IMAGE} AS runtime

ENV PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:${PATH}"

COPY --from=builder /opt/venv /opt/venv

WORKDIR /app
COPY . .

RUN python manage.py collectstatic --noinput

# script has CRLF after a windows checkout, so it would not start
RUN sed -i 's/\r$//' /app/entrypoint.sh && chmod +x /app/entrypoint.sh

RUN useradd -m appuser && chown -R appuser:appuser /app

# Run the application without root privileges.
USER appuser

EXPOSE 8000

ENTRYPOINT ["/app/entrypoint.sh"]
