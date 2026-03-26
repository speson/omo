#!/usr/bin/env bash
# Signal that the agent believes the task is complete.
# If oracle_verify is enabled, transitions to verification_pending phase.
# If not, transitions to verified phase (loop will end on next stop).
set -eu

STATE_FILE=".claude/state/ralph-loop.json"

# JSON field reader: prefers jq, falls back to grep+cut
json_raw()  { if command -v jq >/dev/null 2>&1; then jq -r ".$1" "$2"; else grep -o "\"$1\":[a-z0-9]*" "$2" | cut -d: -f2; fi; }

# JSON phase updater: prefers jq, falls back to sed (handles both compact and pretty JSON)
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

oracle_verify=$(json_raw oracle_verify "${STATE_FILE}")

if [ "${oracle_verify}" = "true" ]; then
  # Transition to verification_pending — Oracle must verify
  set_phase "verification_pending"
  echo "[Ralph Loop] Task marked as done. Oracle verification required."
else
  # No Oracle — transition directly to verified
  set_phase "verified"
  echo "[Ralph Loop] Task marked as done. Loop will end."
fi
