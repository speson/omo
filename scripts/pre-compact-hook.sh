#!/usr/bin/env bash
# PreCompact hook — inject critical state summary before context compaction
# Input: stdin JSON
# Output: stdout JSON with hookSpecificOutput.systemMessage
set -eu

project_dir="${CLAUDE_PROJECT_DIR:-.}"
script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

# Read stdin JSON (drained; no fields currently inspected)
# shellcheck disable=SC2034
input=""
if [ ! -t 0 ]; then
  # shellcheck disable=SC2034
  input=$(cat)
fi

state_msg=""

# Check for active boulder task
if bash "${script_dir}/boulder-check.sh" >/dev/null 2>&1; then
  boulder_file="${project_dir}/.claude/state/boulder.json"
  if command -v jq >/dev/null 2>&1; then
    task_slug=$(jq -r '.task_slug' "${boulder_file}")
    goal=$(jq -r '.goal' "${boulder_file}")
    attempts=$(jq -r '.attempts' "${boulder_file}")
    max_attempts=$(jq -r '.max_attempts' "${boulder_file}")
  else
    task_slug=$(grep -o '"task_slug":"[^"]*"' "${boulder_file}" | cut -d'"' -f4)
    goal=$(grep -o '"goal":"[^"]*"' "${boulder_file}" | cut -d'"' -f4)
    attempts=$(grep -o '"attempts":[0-9]*' "${boulder_file}" | cut -d: -f2)
    max_attempts=$(grep -o '"max_attempts":[0-9]*' "${boulder_file}" | cut -d: -f2)
  fi
  state_msg="Active boulder: ${task_slug} (attempt ${attempts}/${max_attempts}). Goal: ${goal}."
fi

# Check for current task file
current_task_path=""
current_task_file="${project_dir}/.claude/state/current-task.txt"
if [ -f "${current_task_file}" ]; then
  current_task_path=$(cat "${current_task_file}" 2>/dev/null || true)
  if [ -n "${current_task_path}" ]; then
    if [ -n "${state_msg}" ]; then
      state_msg="${state_msg} Current task: ${current_task_path}."
    else
      state_msg="Current task: ${current_task_path}."
    fi
  fi
fi

# Check for latest handoff
handoffs_dir="${project_dir}/.claude/state/handoffs"
if [ -d "${handoffs_dir}" ]; then
  # shellcheck disable=SC2012
  latest_handoff=$(ls -t "${handoffs_dir}"/* 2>/dev/null | head -1 || true)
  if [ -n "${latest_handoff}" ] && [ -f "${latest_handoff}" ]; then
    handoff_summary=$(head -3 "${latest_handoff}" 2>/dev/null | tr '\n' ' ' || true)
    if [ -n "${handoff_summary}" ]; then
      if [ -n "${state_msg}" ]; then
        state_msg="${state_msg} Last handoff: ${handoff_summary}"
      else
        state_msg="Last handoff: ${handoff_summary}"
      fi
    fi
  fi
fi

# Exit silently if no state found
if [ -z "${state_msg}" ]; then
  exit 0
fi

system_msg="[omo state] ${state_msg}"

# Output JSON
if command -v jq >/dev/null 2>&1; then
  jq -n \
    --arg msg "${system_msg}" \
    '{hookSpecificOutput: {hookEventName: "PreCompact", systemMessage: $msg}}'
else
  escaped_msg=$(printf '%s' "${system_msg}" | sed 's/\\/\\\\/g; s/"/\\"/g')
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreCompact\",\"systemMessage\":\"${escaped_msg}\"}}"
fi
