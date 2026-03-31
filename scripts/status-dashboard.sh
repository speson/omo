#!/usr/bin/env bash
# Show unified omo status dashboard across all state subsystems.
# Usage: bash scripts/status-dashboard.sh
set -eu

project_dir="${CLAUDE_PROJECT_DIR:-.}"
script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

# shellcheck source=json-helpers.sh
source "${script_dir}/json-helpers.sh"

echo "omo Status Dashboard"
echo "════════════════════"
echo ""

# ─── Boulder ──────────────────────────────────────────────────────────────────
echo "Boulder"
boulder_file="${project_dir}/.claude/state/boulder.json"
if [ -f "${boulder_file}" ]; then
  b_active=$(json_raw active "${boulder_file}")
  b_slug=$(json_str task_slug "${boulder_file}")
  b_attempts=$(json_num attempts "${boulder_file}")
  b_max=$(json_num max_attempts "${boulder_file}")
  b_outcome=$(json_str last_outcome "${boulder_file}")
  echo "  Task:        ${b_slug:-—}"
  echo "  Active:      ${b_active:-false}"
  echo "  Attempts:    ${b_attempts}/${b_max}"
  echo "  Outcome:     ${b_outcome:-—}"
else
  echo "  inactive"
fi
echo ""

# ─── Ralph Loop ───────────────────────────────────────────────────────────────
echo "Ralph Loop"
ralph_file="${project_dir}/.claude/state/ralph-loop.json"
if [ -f "${ralph_file}" ]; then
  r_active=$(json_raw active "${ralph_file}")
  r_phase=$(json_str phase "${ralph_file}")
  r_iter=$(json_num iteration "${ralph_file}")
  r_max=$(json_num max_iterations "${ralph_file}")
  r_oracle=$(json_raw oracle_verify "${ralph_file}")
  echo "  Active:      ${r_active:-false}"
  echo "  Phase:       ${r_phase:-—}"
  echo "  Iteration:   ${r_iter}/${r_max}"
  echo "  Oracle:      ${r_oracle:-false}"
else
  echo "  Active:      false"
  echo "  Phase:       —"
  echo "  Iteration:   —"
fi
echo ""

# ─── Current Task ─────────────────────────────────────────────────────────────
echo "Current Task"
current_task_file="${project_dir}/.claude/state/current-task.txt"
if [ -f "${current_task_file}" ] && [ -s "${current_task_file}" ]; then
  current_task=$(head -n 1 "${current_task_file}" | tr -d '\r')
  if [ -n "${current_task}" ] && [ "${current_task}" != "idle" ]; then
    echo "  File:        ${current_task}"
  else
    echo "  none"
  fi
else
  echo "  none"
fi
echo ""

# ─── Latest Handoff ───────────────────────────────────────────────────────────
echo "Latest Handoff"
handoffs_dir="${project_dir}/.claude/state/handoffs"
if [ -d "${handoffs_dir}" ]; then
  latest_handoff=$(ls -t "${handoffs_dir}"/*.md 2>/dev/null | head -n 1 || true)
  if [ -n "${latest_handoff}" ]; then
    echo "  File:        ${latest_handoff}"
  else
    echo "  none"
  fi
else
  echo "  none"
fi
echo ""

# ─── Teams ────────────────────────────────────────────────────────────────────
echo "Teams"
teams_dir="${HOME}/.claude/teams"
if [ -d "${teams_dir}" ]; then
  team_found=0
  for team_dir in "${teams_dir}"/*/; do
    [ -d "${team_dir}" ] || continue
    team_name=$(basename "${team_dir}")
    team_cfg="${team_dir}config.json"
    if [ -f "${team_cfg}" ] && command -v jq >/dev/null 2>&1; then
      member_count=$(jq '.members | length' "${team_cfg}" 2>/dev/null || echo "?")
      echo "  ${team_name} (${member_count} members)"
    else
      echo "  ${team_name}"
    fi
    team_found=1
  done
  if [ "${team_found}" -eq 0 ]; then
    echo "  No active teams."
  fi
else
  echo "  No active teams."
fi
echo ""

# ─── Memory ───────────────────────────────────────────────────────────────────
echo "Memory"
memory_index="${project_dir}/.claude/state/memory/index.md"
if [ -f "${memory_index}" ]; then
  line_count=$(wc -l < "${memory_index}" | tr -d ' ')
  echo "  Index:       exists (${line_count} lines)"
else
  echo "  Index:       not found"
fi
