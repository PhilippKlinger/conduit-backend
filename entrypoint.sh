#!/bin/sh
set -eu

POSTGRES_HOST="${POSTGRES_HOST:-database}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
DB_WAIT_TIMEOUT="${DB_WAIT_TIMEOUT:-60}"
GUNICORN_WORKERS="${GUNICORN_WORKERS:-3}"

# no psql client in the slim image, so test the port with python
WAITED=0
until python -c "import socket,sys; socket.create_connection((sys.argv[1], int(sys.argv[2])), 2)" "${POSTGRES_HOST}" "${POSTGRES_PORT}" 2>/dev/null; do
    if [ "${WAITED}" -ge "${DB_WAIT_TIMEOUT}" ]; then
        echo "[entrypoint] PostgreSQL not reachable after ${DB_WAIT_TIMEOUT}s" >&2
        exit 1
    fi
    echo "[entrypoint] waiting for PostgreSQL at ${POSTGRES_HOST}:${POSTGRES_PORT}"
    WAITED=$((WAITED + 2))
    sleep 2
done

# Apply pending schema changes before accepting application traffic.
echo "[entrypoint] applying database migrations"
python manage.py migrate --noinput

# Exec keeps Gunicorn as PID 1 so Docker can forward stop signals correctly.
echo "[entrypoint] starting Gunicorn on 0.0.0.0:8000"
exec gunicorn conduit.wsgi:application \
    --bind 0.0.0.0:8000 \
    --workers "${GUNICORN_WORKERS}" \
    --access-logfile - \
    --error-logfile -
