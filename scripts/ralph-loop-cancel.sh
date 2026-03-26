#!/usr/bin/env bash
# Cancel an active ralph-loop
set -eu

STATE_FILE=".claude/state/ralph-loop.json"

# JSON field reader: prefers jq, falls back to grep+cut
json_raw()  { if command -v jq >/dev/null 2>&1; then jq -r ".$1" "$2"; else grep -o "\"$1\":[a-z0-9]*" "$2" | cut -d: -f2; fi; }

if [ ! -f "${STATE_FILE}" ]; then
  echo "No active Ralph Loop."
  exit 0
fi

iteration=$(json_raw iteration "${STATE_FILE}")
rm -f "${STATE_FILE}"
echo "Ralph Loop cancelled after ${iteration:-0} iteration(s)."
