#!/usr/bin/env bash
# TeammateIdle hook — nudge task list check when a teammate goes idle
# Input: stdin JSON with teammate_name, team_name, etc.
# Output: stdout JSON with hookSpecificOutput.additionalContext
set -eu

# shellcheck disable=SC2034
project_dir="${CLAUDE_PROJECT_DIR:-.}"
script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

# shellcheck source=json-helpers.sh
source "${script_dir}/json-helpers.sh"

# Read stdin JSON
input=""
if [ ! -t 0 ]; then
  input=$(cat)
fi

# Check config: teams.enabled (default true)
teams_enabled=$(bash "${script_dir}/read-config.sh" teams.enabled true)
if [ "${teams_enabled}" != "true" ]; then
  exit 0
fi

# Extract teammate_name from stdin JSON
teammate_name=""
if [ -n "${input}" ]; then
  if command -v jq >/dev/null 2>&1; then
    teammate_name=$(printf '%s' "${input}" | jq -r '.teammate_name // empty' 2>/dev/null || true)
  else
    teammate_name=$(printf '%s' "${input}" | grep -o '"teammate_name":"[^"]*"' | cut -d'"' -f4 2>/dev/null || true)
  fi
fi

context="[omo] Teammate${teammate_name:+ ${teammate_name}} idle. Check task list for unblocked pending tasks."

# Output JSON
if command -v jq >/dev/null 2>&1; then
  jq -n \
    --arg ctx "${context}" \
    '{hookSpecificOutput: {hookEventName: "TeammateIdle", additionalContext: $ctx}}'
else
  escaped_ctx=$(json_escape "${context}")
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"TeammateIdle\",\"additionalContext\":\"${escaped_ctx}\"}}"
fi
