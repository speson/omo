#!/usr/bin/env bash
# Mark a Boulder task as complete
set -eu

project_dir="${CLAUDE_PROJECT_DIR:-.}"
boulder_file="${project_dir}/.claude/state/boulder.json"

if [ ! -f "${boulder_file}" ]; then
  echo "No active boulder to complete." >&2
  exit 1
fi

now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if command -v jq >/dev/null 2>&1; then
  tmp_file="${boulder_file}.tmp"
  jq --arg now "${now}" '
    .active = false |
    .last_outcome = "completed" |
    .updated_at = $now
  ' "${boulder_file}" > "${tmp_file}"
  mv "${tmp_file}" "${boulder_file}"
else
  sed -i.bak \
    -e 's/"active":true/"active":false/' \
    -e "s/\"last_outcome\":\"[^\"]*\"/\"last_outcome\":\"completed\"/" \
    -e "s/\"updated_at\":\"[^\"]*\"/\"updated_at\":\"${now}\"/" \
    "${boulder_file}"
  rm -f "${boulder_file}.bak"
fi

# Read slug for output
if command -v jq >/dev/null 2>&1; then
  slug=$(jq -r '.task_slug' "${boulder_file}")
  attempts=$(jq -r '.attempts' "${boulder_file}")
else
  slug=$(grep -o '"task_slug":"[^"]*"' "${boulder_file}" | cut -d'"' -f4)
  attempts=$(grep -o '"attempts":[0-9]*' "${boulder_file}" | cut -d: -f2)
fi

echo "[Boulder] Completed: ${slug} after ${attempts} attempt(s)"
