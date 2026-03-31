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

# shellcheck source=json-helpers.sh
source "$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)/json-helpers.sh"

auto_resume=$(json_raw auto_resume "${boulder_file}")
if [ "${auto_resume}" != "true" ]; then
  exit 0
fi

task_slug=$(json_str task_slug "${boulder_file}")
attempts=$(json_num attempts "${boulder_file}")
max_attempts=$(json_num max_attempts "${boulder_file}")

context="[omo] Pending task: ${task_slug} (attempt ${attempts}/${max_attempts}). Run #rw to resume."

# Output JSON
if command -v jq >/dev/null 2>&1; then
  jq -n \
    --arg ctx "${context}" \
    '{hookSpecificOutput: {hookEventName: "Notification", additionalContext: $ctx}}'
else
  escaped_ctx=$(json_escape "${context}")
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"Notification\",\"additionalContext\":\"${escaped_ctx}\"}}"
fi
