#!/usr/bin/env bash
# Thin wrapper: delegates to generate_version.py for Ver.YYYY.MM.XYZ.ENV (Z = commits today on dev_main).
# Run from khono_recruite/ or repo root; script dir is khono_recruite/scripts/.
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KHONO_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$KHONO_ROOT"
if command -v python3 >/dev/null 2>&1; then
  exec python3 scripts/generate_version.py
fi
exec python scripts/generate_version.py
