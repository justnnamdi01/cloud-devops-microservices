#!/usr/bin/env bash
set -euo pipefail

# Wait for Postgres to be reachable on host:port using a small Python socket check.
# This avoids installing postgres client tools in the API image.
echo "Waiting for database to be reachable..."
python - <<'PY'
import socket, time, os, sys
host = os.environ.get('DB_HOST', 'db')
port = int(os.environ.get('DB_PORT', '5432'))
timeout = 2
retries = 60
for i in range(retries):
    try:
        s = socket.create_connection((host, port), timeout)
        s.close()
        print('Database is reachable')
        sys.exit(0)
    except Exception:
        print(f'Waiting for {host}:{port} ({i+1}/{retries})')
        time.sleep(2)
print('Timed out waiting for database')
sys.exit(1)
PY

echo "Running alembic migrations..."
alembic upgrade head

echo "Starting application..."
exec "$@"