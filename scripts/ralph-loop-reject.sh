#!/usr/bin/env bash
# Signal that Oracle rejected the verification. Transitions back to working phase.
# The agent must fix issues and try again.
set -eu

STATE_FILE=".claude/state/ralph-loop.json"

if [ ! -f "${STATE_FILE}" ]; then
  echo "No active Ralph Loop." >&2
  exit 1
fi

tmp_file="${STATE_FILE}.tmp"
sed 's/"phase":"verification_pending"/"phase":"working"/' "${STATE_FILE}" > "${tmp_file}"
mv "${tmp_file}" "${STATE_FILE}"
echo "[Ralph Loop] Oracle rejected. Back to working phase. Fix the issues."
