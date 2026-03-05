#!/usr/bin/env bash
# generate_version.sh – outputs version string Ver.YYYY.MM.XYZ.ENV for build-time --dart-define=APP_VERSION
# X = week of month (A–F), Y = day of week (A=Mon … G=Sun), Z = commit count on origin/dev_main (or HEAD/0)

set -e

# Run from repo root so git commands see the full repo (e.g. when build runs from khono_recruite/)
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || true
if [ -n "${REPO_ROOT:-}" ]; then
  cd "$REPO_ROOT"
fi

# Year and month
YEAR="$(date +%Y)"
MONTH="$(date +%m)"

# Week of month: 1→A, 2→B, … 6→F
DAY_OF_MONTH="$(date +%d)"
WEEK_NUM=$(( (10#$DAY_OF_MONTH - 1) / 7 + 1 ))
# Cap at 6 for letter F
if [ "$WEEK_NUM" -gt 6 ]; then
  WEEK_NUM=6
fi
WEEK_LETTER="$(printf '%c' $((64 + WEEK_NUM)))"

# Day of week: 1=Mon … 7=Sun → A–G
DOW_NUM="$(date +%u)"
DAY_LETTER="$(printf '%c' $((64 + DOW_NUM)))"

# Commit count: prefer origin/dev_main, else HEAD, else 0
COMMIT_COUNT="$(git rev-list --count origin/dev_main 2>/dev/null)" || true
if [ -z "${COMMIT_COUNT:-}" ]; then
  COMMIT_COUNT="$(git rev-list --count HEAD 2>/dev/null)" || true
fi
COMMIT_COUNT="${COMMIT_COUNT:-0}"

# Environment
ENV="${APP_ENV:-DEV}"

echo "Ver.${YEAR}.${MONTH}.${WEEK_LETTER}${DAY_LETTER}${COMMIT_COUNT}.${ENV}"
