#!/usr/bin/env bash
set -euo pipefail

export FLUTTER_SUPPRESS_ANALYTICS=true
export PUB_ENVIRONMENT=render

WORKDIR="$(pwd)"
FLUTTER_DIR="${WORKDIR}/.flutter"
ARCHIVE_PATH="/tmp/flutter.tar.xz"

if [ ! -d "${FLUTTER_DIR}" ]; then
  # Fetch the Flutter archive URL into a temporary variable
  DOWNLOAD_OUTPUT="$(python3 - <<'PY'
import json, urllib.request
url = "https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json"
data = json.load(urllib.request.urlopen(url))
stable_hash = data["current_release"]["stable"]
release = next(r for r in data["releases"] if r["hash"] == stable_hash)
archive = release["archive"]
print(f"{data['base_url']}/{archive}")
PY
  )"

  # Extract the final non-empty line (guard against extraneous logs), trim CRs
  DOWNLOAD_URL="$(echo "${DOWNLOAD_OUTPUT}" | awk 'NF{last=$0} END{print last}' | tr -d '\r')"

  echo "Downloading Flutter from: ${DOWNLOAD_URL}"

  curl -fsSL "${DOWNLOAD_URL}" -o "${ARCHIVE_PATH}"
  mkdir -p "${FLUTTER_DIR}"
  tar -xf "${ARCHIVE_PATH}" -C "${FLUTTER_DIR}" --strip-components=1
fi

export PATH="${FLUTTER_DIR}/bin:${PATH}"

flutter --version
flutter config --enable-web
flutter pub get

# Use BACKEND_URL (or API_BASE) at build time so the web app calls the deployed API.
API_BASE="${API_BASE:-${BACKEND_URL:-http://127.0.0.1:5001}}"
PUBLIC_BASE="${PUBLIC_API_BASE:-${API_BASE}}"
if [ -z "${BACKEND_URL:-}" ]; then
  echo "WARNING: BACKEND_URL is not set for recruitment-web. Build will use API_BASE=${API_BASE}. Set BACKEND_URL in Render (Environment) to your API URL (e.g. https://recruitment-api-zovg.onrender.com) and redeploy."
fi
echo "Building Flutter web with API_BASE=${API_BASE}"
flutter build web --release \
  --dart-define=API_BASE="$API_BASE" \
  --dart-define=PUBLIC_API_BASE="$PUBLIC_BASE"
