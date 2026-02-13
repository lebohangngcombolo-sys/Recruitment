#!/usr/bin/env bash
set -euo pipefail

export FLASK_APP=app:create_app

# Run migrations before starting the web server
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
