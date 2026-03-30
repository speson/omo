#!/usr/bin/env bash
# Mark a Boulder task as complete
set -eu

project_dir="${CLAUDE_PROJECT_DIR:-.}"
boulder_file="${project_dir}/.claude/state/boulder.json"
script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

enabled=$(bash "${script_dir}/read-config.sh" boulder.enabled true 2>/dev/null || echo "true")
if [ "${enabled}" != "true" ]; then
  exit 0
fi

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
    -e 's/"active" *: *true/"active": false/' \
    -e "s/\"last_outcome\" *: *\"[^\"]*\"/\"last_outcome\": \"completed\"/" \
    -e "s/\"updated_at\" *: *\"[^\"]*\"/\"updated_at\": \"${now}\"/" \
    "${boulder_file}"
  rm -f "${boulder_file}.bak"
fi

# Read slug for output
if command -v jq >/dev/null 2>&1; then
  slug=$(jq -r '.task_slug' "${boulder_file}")
  attempts=$(jq -r '.attempts' "${boulder_file}")
else
  slug=$(grep -o '"task_slug" *: *"[^"]*"' "${boulder_file}" | cut -d'"' -f4)
  attempts=$(grep -o '"attempts" *: *[0-9]*' "${boulder_file}" | sed 's/.*: *//')
fi

echo "[Boulder] Completed: ${slug} after ${attempts} attempt(s)"

# Notify if configured
script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
notify=$(bash "${script_dir}/read-config.sh" teams.notify_on_completion true 2>/dev/null || echo "true")
if [ "${notify}" = "true" ]; then
  bash "${script_dir}/notify.sh" "omo" "Boulder completed: ${slug}" 2>/dev/null || true
fi
