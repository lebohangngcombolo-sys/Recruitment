#!/usr/bin/env bash
set -euo pipefail

export FLUTTER_SUPPRESS_ANALYTICS=true
export PUB_ENVIRONMENT=render

WORKDIR="$(pwd)"
FLUTTER_DIR="${WORKDIR}/.flutter"
ARCHIVE_PATH="/tmp/flutter.tar.xz"

if [ ! -d "${FLUTTER_DIR}" ]; then
  # Fetch the Flutter archive URL and ensure we only keep the final non-empty line
  DOWNLOAD_URL="$(python3 - <<'PY'
import json, urllib.request
url = "https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json"
data = json.load(urllib.request.urlopen(url))
stable_hash = data["current_release"]["stable"]
release = next(r for r in data["releases"] if r["hash"] == stable_hash)
archive = release["archive"]
print(f"{data['base_url']}/{archive}")
PY
  | awk 'NF{last=$0} END{print last}')"

  # strip any stray carriage returns that can break curl on linux shells
  DOWNLOAD_URL="$(echo "${DOWNLOAD_URL}" | tr -d '\r')"

  echo "Downloading Flutter from: ${DOWNLOAD_URL}"

  curl -fsSL "${DOWNLOAD_URL}" -o "${ARCHIVE_PATH}"
  mkdir -p "${FLUTTER_DIR}"
  tar -xf "${ARCHIVE_PATH}" -C "${FLUTTER_DIR}" --strip-components=1
fi

export PATH="${FLUTTER_DIR}/bin:${PATH}"

flutter --version
flutter config --enable-web
flutter pub get
flutter build web --release
