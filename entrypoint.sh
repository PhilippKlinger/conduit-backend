#!/bin/sh
set -eu

POSTGRES_HOST="${POSTGRES_HOST:-database}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
DB_WAIT_TIMEOUT="${DB_WAIT_TIMEOUT:-60}"
GUNICORN_BIND="${GUNICORN_BIND:-0.0.0.0:8000}"
GUNICORN_WORKERS="${GUNICORN_WORKERS:-3}"

# The slim image has no PostgreSQL client tools, so use Python's standard
# library to wait until the database port accepts connections.
echo "[entrypoint] waiting for PostgreSQL at ${POSTGRES_HOST}:${POSTGRES_PORT}"
python - "${POSTGRES_HOST}" "${POSTGRES_PORT}" "${DB_WAIT_TIMEOUT}" <<'PY'
import socket
import sys
import time

host = sys.argv[1]
port = int(sys.argv[2])
deadline = time.time() + int(sys.argv[3])

while time.time() < deadline:
    try:
        connection = socket.create_connection((host, port), timeout=2)
        connection.close()
        sys.exit(0)
    except OSError:
        time.sleep(1)

print("[entrypoint] PostgreSQL did not become reachable", file=sys.stderr)
sys.exit(1)
PY

# Apply pending schema changes before accepting application traffic.
echo "[entrypoint] applying database migrations"
python manage.py migrate --noinput

# Exec keeps Gunicorn as PID 1 so Docker can forward stop signals correctly.
echo "[entrypoint] starting Gunicorn on ${GUNICORN_BIND}"
exec gunicorn conduit.wsgi:application \
    --bind "${GUNICORN_BIND}" \
    --workers "${GUNICORN_WORKERS}" \
    --access-logfile - \
    --error-logfile -
