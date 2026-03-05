#!/usr/bin/env bash
# flutter_run_with_version.sh – run Flutter web locally with a generated APP_VERSION
# This mirrors the Render build behaviour (scripts/generate_version.sh) so local runs
# get a realistic Ver.YYYY.MM.XYZ.ENV build stamp instead of the synthetic LOCAL default.

set -euo pipefail

# Resolve repo root so git commands work even when invoked from subdirectories.
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "${REPO_ROOT}"

cd khono_recruite

# Derive API_BASE in the same way as render_build.sh for consistent local testing.
API_BASE="${API_BASE:-${BACKEND_URL:-http://127.0.0.1:5001}}"
PUBLIC_BASE="${PUBLIC_API_BASE:-${API_BASE}}"

# Generate build-time version string. Fall back to a clearly synthetic LOCAL value.
APP_VERSION="$(bash scripts/generate_version.sh 2>/dev/null || echo 'Ver.0.0.0.LOCAL')"
echo "Running Flutter web with API_BASE=${API_BASE} APP_VERSION=${APP_VERSION}"

flutter run -d chrome \
  --dart-define=API_BASE="${API_BASE}" \
  --dart-define=PUBLIC_API_BASE="${PUBLIC_BASE}" \
  --dart-define=APP_VERSION="${APP_VERSION}"

