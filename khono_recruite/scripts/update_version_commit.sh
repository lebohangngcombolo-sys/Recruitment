#!/usr/bin/env bash
# Update app_version_generated.dart and commit it so branches that pull from dev_main
# get the latest version and plain "flutter run" displays it.
# Run from khono_recruite/ (e.g. after merging to dev_main). Best run on dev_main.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
KHONO_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$KHONO_ROOT"

bash scripts/update_version_file.sh
VERSION_FILE="lib/utils/app_version_generated.dart"
if [ ! -f "$VERSION_FILE" ]; then
  echo "Version file not found: $VERSION_FILE" >&2
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"
if [ -d "khono_recruite" ]; then
  REL_PATH="khono_recruite/$VERSION_FILE"
else
  REL_PATH="$VERSION_FILE"
fi
git add "$REL_PATH"
if git status -s "$REL_PATH" | grep -q '^[AM]'; then
  git commit -m "chore: update app version stamp (for branches that pull from dev_main)"
  echo "Committed $REL_PATH. Push to dev_main so other branches get this version when they pull."
else
  echo "No change in version file; nothing to commit."
fi
