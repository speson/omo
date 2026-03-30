#!/usr/bin/env bash
# Show current team status summary
# Usage: team-status.sh [team-name]
set -eu

team_name="${1:-}"
teams_dir="${HOME}/.claude/teams"

if [ ! -d "${teams_dir}" ]; then
  echo "No teams directory found."
  exit 0
fi

if [ -n "${team_name}" ]; then
  config_file="${teams_dir}/${team_name}/config.json"
  if [ ! -f "${config_file}" ]; then
    echo "Team '${team_name}' not found."
    exit 1
  fi
  echo "Team: ${team_name}"
  if command -v jq >/dev/null 2>&1; then
    member_count=$(jq '.members | length' "${config_file}" 2>/dev/null || echo "?")
    echo "  Members: ${member_count}"
    jq -r '.members[] | "  - \(.name) (\(.agentType))"' "${config_file}" 2>/dev/null || true
  else
    echo "  (install jq for detailed team info)"
  fi
else
  # List all teams
  found=0
  for dir in "${teams_dir}"/*/; do
    [ -d "${dir}" ] || continue
    name=$(basename "${dir}")
    config="${dir}config.json"
    found=1
    if [ -f "${config}" ] && command -v jq >/dev/null 2>&1; then
      member_count=$(jq '.members | length' "${config}" 2>/dev/null || echo "?")
      echo "${name} (${member_count} members)"
    else
      echo "${name}"
    fi
  done
  if [ "${found}" -eq 0 ]; then
    echo "No active teams."
  fi
fi
