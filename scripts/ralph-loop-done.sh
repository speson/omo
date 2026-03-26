#!/usr/bin/env bash
# Signal that the agent believes the task is complete.
# If oracle_verify is enabled, transitions to verification_pending phase.
# If not, transitions to verified phase (loop will end on next stop).
set -eu

STATE_FILE=".claude/state/ralph-loop.json"

if [ ! -f "${STATE_FILE}" ]; then
  echo "No active Ralph Loop." >&2
  exit 1
fi

oracle_verify=$(cat "${STATE_FILE}" | grep -o '"oracle_verify":[a-z]*' | cut -d: -f2)

if [ "${oracle_verify}" = "true" ]; then
  # Transition to verification_pending — Oracle must verify
  tmp_file="${STATE_FILE}.tmp"
  sed 's/"phase":"working"/"phase":"verification_pending"/' "${STATE_FILE}" > "${tmp_file}"
  mv "${tmp_file}" "${STATE_FILE}"
  echo "[Ralph Loop] Task marked as done. Oracle verification required."
else
  # No Oracle — transition directly to verified
  tmp_file="${STATE_FILE}.tmp"
  sed 's/"phase":"working"/"phase":"verified"/' "${STATE_FILE}" > "${tmp_file}"
  mv "${tmp_file}" "${STATE_FILE}"
  echo "[Ralph Loop] Task marked as done. Loop will end."
fi
