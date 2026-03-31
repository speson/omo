#!/usr/bin/env bash
# SessionStart hook — inject Boulder task context on session start/resume
# Input: stdin JSON with session_id, source, etc.
# Output: stdout JSON with hookSpecificOutput.additionalContext
set -eu

project_dir="${CLAUDE_PROJECT_DIR:-.}"
script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

# Read stdin JSON
input=""
if [ ! -t 0 ]; then
  input=$(cat)
fi

# Check source — skip for "clear" sessions
if [ -n "${input}" ]; then
  source_type=$(echo "${input}" | grep -o '"source" *: *"[^"]*"' | cut -d'"' -f4 2>/dev/null || true)
  if [ "${source_type}" = "clear" ]; then
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

task_slug=$(json_str task_slug "${boulder_file}")
goal=$(json_str goal "${boulder_file}")
attempts=$(json_num attempts "${boulder_file}")
max_attempts=$(json_num max_attempts "${boulder_file}")
last_outcome=$(json_str last_outcome "${boulder_file}")

# Build context message (max 5 lines)
context="[omo] Active task: ${task_slug} (attempt ${attempts}/${max_attempts})"
context="${context}\nGoal: ${goal}"
context="${context}\nLast outcome: ${last_outcome}"

# Check for current task file
if [ -f "${project_dir}/.claude/state/current-task.txt" ]; then
  task_file=$(cat "${project_dir}/.claude/state/current-task.txt" 2>/dev/null || true)
  if [ -n "${task_file}" ] && [ -f "${task_file}" ]; then
    context="${context}\nTask note: ${task_file}"
  fi
fi

context="${context}\nRun #rw to resume or #ho to review handoff."

# Output JSON
if command -v jq >/dev/null 2>&1; then
  jq -n \
    --arg ctx "$(printf '%b' "${context}")" \
    '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
else
  # Manual JSON construction
  escaped_ctx=$(json_escape "$(printf '%b' "${context}")")
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"SessionStart\",\"additionalContext\":\"${escaped_ctx}\"}}"
fi
