#!/usr/bin/env bash
# SubagentStop hook — record progress and recommend oracle escalation when needed
# Input: stdin JSON with agent_id, agent_type, last_assistant_message, etc.
# Output: stdout JSON with hookSpecificOutput.additionalContext (only when escalation needed)
set -eu

# shellcheck disable=SC2034
project_dir="${CLAUDE_PROJECT_DIR:-.}"
script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

# Read stdin JSON
input=""
if [ ! -t 0 ]; then
  input=$(cat)
fi

# Parse agent_type from input JSON
agent_type="unknown"
if [ -n "${input}" ]; then
  if command -v jq >/dev/null 2>&1; then
    agent_type=$(echo "${input}" | jq -r '.agent_type // "unknown"' 2>/dev/null || echo "unknown")
  elif command -v python3 >/dev/null 2>&1; then
    agent_type=$(echo "${input}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('agent_type','unknown'))" 2>/dev/null || echo "unknown")
  else
    agent_type=$(echo "${input}" | grep -o '"agent_type"[[:space:]]*:[[:space:]]*"[^"]*"' | grep -o '"[^"]*"$' | tr -d '"' 2>/dev/null || echo "unknown")
  fi
fi

# Check config: auto_escalation (default true)
auto_escalation=$(bash "${script_dir}/read-config.sh" teams.auto_escalation true)
if [ "${auto_escalation}" != "true" ]; then
  exit 0
fi

# Check briefings for escalation signals; exit code 2 means escalation recommended
escalation_exit=0
bash "${script_dir}/escalation-check.sh" >/dev/null 2>&1 || escalation_exit=$?

if [ "${escalation_exit}" -eq 2 ]; then
  context="[omo] Subagent (${agent_type}) completed with low confidence. Consider escalating to oracle."
  if command -v jq >/dev/null 2>&1; then
    jq -n \
      --arg ctx "${context}" \
      '{hookSpecificOutput: {hookEventName: "SubagentStop", additionalContext: $ctx}}'
  else
    escaped_ctx=$(printf '%s' "${context}" | sed 's/\\/\\\\/g; s/"/\\"/g')
    echo "{\"hookSpecificOutput\":{\"hookEventName\":\"SubagentStop\",\"additionalContext\":\"${escaped_ctx}\"}}"
  fi
fi
