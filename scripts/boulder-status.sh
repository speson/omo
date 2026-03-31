#!/usr/bin/env bash
# Show current Boulder status (human-readable)
set -eu

project_dir="${CLAUDE_PROJECT_DIR:-.}"
boulder_file="${project_dir}/.claude/state/boulder.json"

if [ ! -f "${boulder_file}" ]; then
  echo "No boulder state found."
  exit 0
fi

# shellcheck source=json-helpers.sh
source "$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)/json-helpers.sh"

active=$(json_raw active "${boulder_file}")
slug=$(json_str task_slug "${boulder_file}")
goal=$(json_str goal "${boulder_file}")
attempts=$(json_raw attempts "${boulder_file}")
max=$(json_raw max_attempts "${boulder_file}")
consec=$(json_raw consecutive_failures "${boulder_file}")
outcome=$(json_str last_outcome "${boulder_file}")
auto=$(json_raw auto_resume "${boulder_file}")
created=$(json_str created_at "${boulder_file}")
updated=$(json_str updated_at "${boulder_file}")

echo "Boulder Status"
echo "══════════════"
echo "  Task:        ${slug}"
echo "  Goal:        ${goal}"
echo "  Active:      ${active}"
echo "  Attempts:    ${attempts}/${max}"
echo "  Failures:    ${consec} consecutive"
echo "  Outcome:     ${outcome}"
echo "  Auto-resume: ${auto}"
echo "  Created:     ${created}"
echo "  Updated:     ${updated}"

if [ "${active}" = "true" ] && [ "${consec}" -ge 2 ] 2>/dev/null; then
  echo ""
  echo "  ⚠ Multiple consecutive failures. Consider escalating to oracle."
fi
