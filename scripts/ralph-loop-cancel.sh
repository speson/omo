#!/usr/bin/env bash
# Cancel an active ralph-loop
set -eu

STATE_FILE=".claude/state/ralph-loop.json"

if [ ! -f "${STATE_FILE}" ]; then
  echo "No active Ralph Loop."
  exit 0
fi

iteration=$(cat "${STATE_FILE}" | grep -o '"iteration":[0-9]*' | cut -d: -f2)
rm -f "${STATE_FILE}"
echo "Ralph Loop cancelled after ${iteration:-0} iteration(s)."
