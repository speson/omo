#!/usr/bin/env bash
# Check if a Boulder task can be resumed
# Exit 0 = resumable, Exit 1 = not resumable
set -eu

project_dir="${CLAUDE_PROJECT_DIR:-.}"
boulder_file="${project_dir}/.claude/state/boulder.json"

if [ ! -f "${boulder_file}" ]; then
  exit 1
fi

# JSON field reader
json_str() { if command -v jq >/dev/null 2>&1; then jq -r ".$1" "$2"; else grep -o "\"$1\":\"[^\"]*\"" "$2" | cut -d'"' -f4; fi; }
json_raw() { if command -v jq >/dev/null 2>&1; then jq -r ".$1" "$2"; else grep -o "\"$1\":[a-z0-9]*" "$2" | cut -d: -f2; fi; }

active=$(json_raw active "${boulder_file}")
if [ "${active}" != "true" ]; then
  exit 1
fi

attempts=$(json_raw attempts "${boulder_file}")
max_attempts=$(json_raw max_attempts "${boulder_file}")
last_outcome=$(json_str last_outcome "${boulder_file}")
goal=$(json_str goal "${boulder_file}")
task_slug=$(json_str task_slug "${boulder_file}")

if [ "${attempts}" -ge "${max_attempts}" ] 2>/dev/null; then
  echo "[Boulder] Max attempts (${max_attempts}) reached for: ${task_slug}" >&2
  exit 1
fi

echo "[Boulder] Active task: ${task_slug} (attempt ${attempts}/${max_attempts})"
echo "  Goal: ${goal}"
echo "  Last outcome: ${last_outcome}"
exit 0
