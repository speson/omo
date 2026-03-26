#!/usr/bin/env bash
# Read recent briefings from .claude/state/briefings/
# Usage: read-briefings.sh [count] [task-slug-filter]
set -eu

count="${1:-5}"
filter="${2:-}"

BRIEFINGS_DIR=".claude/state/briefings"

if [ ! -d "${BRIEFINGS_DIR}" ]; then
  echo "No briefings directory found."
  exit 0
fi

if [ -n "${filter}" ]; then
  files=$(ls -t "${BRIEFINGS_DIR}"/${filter}*.md 2>/dev/null | head -n "${count}")
else
  files=$(ls -t "${BRIEFINGS_DIR}"/*.md 2>/dev/null | head -n "${count}")
fi

if [ -z "${files}" ]; then
  echo "No briefings found."
  exit 0
fi

echo "=== Recent Briefings (${count} max) ==="
echo ""

for f in ${files}; do
  echo "--- $(basename "${f}") ---"
  cat "${f}"
  echo ""
done
