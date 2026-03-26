#!/usr/bin/env bash
# Signal that Oracle has verified the task. Transitions to verified phase.
# The Stop hook will allow the agent to stop on the next attempt.
set -eu

STATE_FILE=".claude/state/ralph-loop.json"

# JSON field reader: prefers jq, falls back to grep+cut
json_str()  { if command -v jq >/dev/null 2>&1; then jq -r ".$1" "$2"; else grep -o "\"$1\":\"[^\"]*\"" "$2" | cut -d'"' -f4; fi; }

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

phase=$(json_str phase "${STATE_FILE}")

if [ "${phase}" != "verification_pending" ]; then
  echo "Loop is not in verification_pending phase (current: ${phase})." >&2
  exit 1
fi

set_phase "verified"
echo "[Ralph Loop] Oracle verification passed. Loop will end."
