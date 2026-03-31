#!/usr/bin/env bash
# Cancel an active ralph-loop
set -eu

STATE_FILE=".claude/state/ralph-loop.json"

# shellcheck source=json-helpers.sh
source "$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)/json-helpers.sh"

if [ ! -f "${STATE_FILE}" ]; then
  echo "No active Ralph Loop."
  exit 0
fi

iteration=$(json_raw iteration "${STATE_FILE}")
rm -f "${STATE_FILE}"
echo "Ralph Loop cancelled after ${iteration:-0} iteration(s)."
