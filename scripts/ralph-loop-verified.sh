#!/usr/bin/env bash
# Signal that Oracle has verified the task. Transitions to verified phase.
# The Stop hook will allow the agent to stop on the next attempt.
set -eu

STATE_FILE=".claude/state/ralph-loop.json"

if [ ! -f "${STATE_FILE}" ]; then
  echo "No active Ralph Loop." >&2
  exit 1
fi

phase=$(cat "${STATE_FILE}" | grep -o '"phase":"[^"]*"' | cut -d'"' -f4)

if [ "${phase}" != "verification_pending" ]; then
  echo "Loop is not in verification_pending phase (current: ${phase})." >&2
  exit 1
fi

tmp_file="${STATE_FILE}.tmp"
sed 's/"phase":"verification_pending"/"phase":"verified"/' "${STATE_FILE}" > "${tmp_file}"
mv "${tmp_file}" "${STATE_FILE}"
echo "[Ralph Loop] Oracle verification passed. Loop will end."
