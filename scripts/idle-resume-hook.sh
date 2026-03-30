#!/usr/bin/env bash
# Notification hook — nudge Boulder task resume on idle
# Input: stdin JSON with notification_type
# Output: stdout JSON with hookSpecificOutput.additionalContext
set -eu

project_dir="${CLAUDE_PROJECT_DIR:-.}"
script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

# Read stdin JSON
input=""
if [ ! -t 0 ]; then
  input=$(cat)
fi

# Only respond to idle_prompt notifications
if [ -n "${input}" ]; then
  notif_type=$(echo "${input}" | grep -o '"notification_type" *: *"[^"]*"' | cut -d'"' -f4 2>/dev/null || true)
  if [ "${notif_type}" != "idle_prompt" ]; then
    exit 0
  fi
fi

# Check for active Boulder task
if ! bash "${script_dir}/boulder-check.sh" >/dev/null 2>&1; then
  exit 0
fi

boulder_file="${project_dir}/.claude/state/boulder.json"

# JSON field readers
json_str() { if command -v jq >/dev/null 2>&1; then jq -r ".$1" "$2"; else grep -o "\"$1\" *: *\"[^\"]*\"" "$2" | cut -d'"' -f4; fi; }
json_raw() { if command -v jq >/dev/null 2>&1; then jq -r ".$1" "$2"; else grep -o "\"$1\" *: *[a-z0-9]*" "$2" | sed 's/.*: *//'; fi; }

auto_resume=$(json_raw auto_resume "${boulder_file}")
if [ "${auto_resume}" != "true" ]; then
  exit 0
fi

task_slug=$(json_str task_slug "${boulder_file}")
attempts=$(json_raw attempts "${boulder_file}")
max_attempts=$(json_raw max_attempts "${boulder_file}")

context="[omo] Pending task: ${task_slug} (attempt ${attempts}/${max_attempts}). Run #rw to resume."

# Output JSON
if command -v jq >/dev/null 2>&1; then
  jq -n \
    --arg ctx "${context}" \
    '{hookSpecificOutput: {hookEventName: "Notification", additionalContext: $ctx}}'
else
  escaped_ctx=$(printf '%s' "${context}" | sed 's/\\/\\\\/g; s/"/\\"/g')
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"Notification\",\"additionalContext\":\"${escaped_ctx}\"}}"
fi
