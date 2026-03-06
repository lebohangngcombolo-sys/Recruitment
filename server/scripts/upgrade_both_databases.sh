#!/usr/bin/env bash
# Apply Flask migrations to both databases:
#   1) DATABASE_URL (recruitement_deploy) — main app DB
#   2) External_Database_URL (recruitment_db_vexi) — deployment DB
# Run from server/: bash scripts/upgrade_both_databases.sh
set -e
cd "$(dirname "$0")/.."
source .venv/bin/activate

echo "=== 1/2 Updating main app DB (DATABASE_URL = recruitement_deploy) ==="
flask db upgrade
echo ""

echo "=== 2/2 Updating deployment DB (External_Database_URL = recruitment_db_vexi) ==="
line=$(grep '^External_Database_URL=' .env 2>/dev/null) || true
if [ -z "$line" ]; then
  echo "ERROR: External_Database_URL not set in .env"
  exit 1
fi
url=$(echo "${line#*=}" | tr -d '\r\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
export DATABASE_URL="${url}?sslmode=require"
flask db upgrade
echo "Done. Both databases updated."
