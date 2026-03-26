#!/usr/bin/env bash
# Signal that Oracle rejected the verification. Transitions back to working phase.
# The agent must fix issues and try again.
set -eu

STATE_FILE=".claude/state/ralph-loop.json"

# JSON phase updater: prefers jq, falls back to sed
set_phase() {
  local new_phase="$1"
  local tmp_file="${STATE_FILE}.tmp"
  if command -v jq >/dev/null 2>&1; then
    jq --arg p "${new_phase}" '.phase = $p' "${STATE_FILE}" > "${tmp_file}"
  else
    sed "s/\"phase\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"phase\":\"${new_phase}\"/" "${STATE_FILE}" > "${tmp_file}"
  fi
  mv "${tmp_file}" "${STATE_FILE}"
}

if [ ! -f "${STATE_FILE}" ]; then
  echo "No active Ralph Loop." >&2
  exit 1
fi

set_phase "working"
echo "[Ralph Loop] Oracle rejected. Back to working phase. Fix the issues."
