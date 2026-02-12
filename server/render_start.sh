#!/usr/bin/env bash
set -euo pipefail

export FLASK_APP=app:create_app

# Run migrations before starting the web server
set +e
python - <<'PY'
import os
import psycopg2

dsn = os.environ.get("DATABASE_URL")
if not dsn:
    raise SystemExit("DATABASE_URL not set")

conn = psycopg2.connect(dsn)
cur = conn.cursor()

def table_exists(name: str) -> bool:
    cur.execute(
        """
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema='public' AND table_name=%s
        """,
        (name,),
    )
    return cur.fetchone() is not None

users_exists = table_exists("users")
alembic_exists = table_exists("alembic_version")
version_num = None
if alembic_exists:
    cur.execute("SELECT version_num FROM alembic_version LIMIT 1")
    row = cur.fetchone()
    version_num = row[0] if row else None

cur.close()
conn.close()

print(f"users_exists={users_exists} alembic_exists={alembic_exists} version_num={version_num}")

# Exit code 10 indicates we should stamp before upgrade
# - Existing schema but no alembic_version (or empty)
# - Or alembic stamped at legacy 5e59a6f99a77 (would otherwise try to run init_schema branch)
if users_exists and ((not alembic_exists) or (not version_num) or (version_num == "5e59a6f99a77")):
    raise SystemExit(10)
PY
PY_EXIT=$?
set -e

if [ "$PY_EXIT" -eq 10 ]; then
  echo "Detected existing schema without alembic_version; stamping to merge revision 8c2b6b1a9d21"
  flask db stamp 8c2b6b1a9d21
elif [ "$PY_EXIT" -ne 0 ]; then
  echo "Pre-migration DB check failed"
  exit "$PY_EXIT"
fi

flask db upgrade

# Start Flask app with eventlet for SocketIO support
# Tune via env vars: GUNICORN_WORKERS, GUNICORN_TIMEOUT, GUNICORN_GRACEFUL_TIMEOUT, GUNICORN_KEEPALIVE
GUNICORN_WORKERS="${GUNICORN_WORKERS:-2}"
GUNICORN_TIMEOUT="${GUNICORN_TIMEOUT:-120}"
GUNICORN_GRACEFUL_TIMEOUT="${GUNICORN_GRACEFUL_TIMEOUT:-30}"
GUNICORN_KEEPALIVE="${GUNICORN_KEEPALIVE:-5}"

exec gunicorn -k eventlet \
  -w "${GUNICORN_WORKERS}" \
  --timeout "${GUNICORN_TIMEOUT}" \
  --graceful-timeout "${GUNICORN_GRACEFUL_TIMEOUT}" \
  --keep-alive "${GUNICORN_KEEPALIVE}" \
  wsgi:app \
  --bind "0.0.0.0:${PORT:-5000}"
