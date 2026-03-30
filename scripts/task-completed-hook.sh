#!/usr/bin/env bash
# TaskCompleted hook — notify on task completion and surface newly unblocked tasks
# Input: stdin JSON with task_id, task_subject, etc.
# Output: stdout JSON with hookSpecificOutput.additionalContext
set -eu

# shellcheck disable=SC2034
project_dir="${CLAUDE_PROJECT_DIR:-.}"
script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

# Read stdin JSON
input=""
if [ ! -t 0 ]; then
  input=$(cat)
fi

# Check config: teams.notify_on_completion (default true)
notify_on_completion=$(bash "${script_dir}/read-config.sh" teams.notify_on_completion true)

# Extract task_subject from stdin JSON
task_subject=""
if [ -n "${input}" ]; then
  if command -v jq >/dev/null 2>&1; then
    task_subject=$(printf '%s' "${input}" | jq -r '.task_subject // empty' 2>/dev/null || true)
  else
    task_subject=$(printf '%s' "${input}" | grep -o '"task_subject":"[^"]*"' | cut -d'"' -f4 2>/dev/null || true)
  fi
fi

# Send OS notification if enabled
if [ "${notify_on_completion}" = "true" ]; then
  notify_msg="Task completed"
  if [ -n "${task_subject}" ]; then
    notify_msg="Task completed: ${task_subject}"
  fi
  bash "${script_dir}/notify.sh" "omo" "${notify_msg}" 2>/dev/null || true
fi

context="[omo] Task completed. Check task list for newly unblocked tasks."

# Output JSON
if command -v jq >/dev/null 2>&1; then
  jq -n \
    --arg ctx "${context}" \
    '{hookSpecificOutput: {hookEventName: "TaskCompleted", additionalContext: $ctx}}'
else
  escaped_ctx=$(printf '%s' "${context}" | sed 's/\\/\\\\/g; s/"/\\"/g')
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"TaskCompleted\",\"additionalContext\":\"${escaped_ctx}\"}}"
fi
