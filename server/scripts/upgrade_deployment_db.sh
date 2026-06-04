#!/usr/bin/env bash
# Run migrations against deployment DB (External_Database_URL from .env).
set -e
cd "$(dirname "$0")/.."
source .venv/bin/activate
line=$(grep '^External_Database_URL=' .env 2>/dev/null) || true
if [ -z "$line" ]; then
  echo "ERROR: External_Database_URL not set in .env"
  exit 1
fi
# Trim trailing CR/LF (Windows .env can have CRLF)
url=$(echo "${line#*=}" | tr -d '\r\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
export DATABASE_URL="${url}?sslmode=require"
echo "Running flask db upgrade against deployment DB..."
flask db upgrade
echo "Done."
