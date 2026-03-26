#!/usr/bin/env bash
# Initialize ralph-loop state file
# Usage: ./scripts/ralph-loop-start.sh "task description" [max_iterations] [completion_promise] [--oracle]
#
# Options:
#   --oracle    Enable Oracle verification (ulw-loop mode)
set -eu

STATE_DIR=".claude/state"
STATE_FILE="${STATE_DIR}/ralph-loop.json"

# Parse arguments
prompt=""
max_iterations=100
completion_promise="DONE"
oracle_verify="false"

for arg in "$@"; do
  case "${arg}" in
    --oracle) oracle_verify="true" ;;
    --max-iterations=*) max_iterations="${arg#*=}" ;;
    --promise=*) completion_promise="${arg#*=}" ;;
    *) [ -z "${prompt}" ] && prompt="${arg}" ;;
  esac
done

if [ -z "${prompt}" ]; then
  echo "Usage: ralph-loop-start.sh \"task\" [--oracle] [--max-iterations=N] [--promise=TEXT]" >&2
  exit 1
fi

mkdir -p "${STATE_DIR}"

cat > "${STATE_FILE}" <<EOF
{
  "active": true,
  "phase": "working",
  "iteration": 0,
  "max_iterations": ${max_iterations},
  "completion_promise": "${completion_promise}",
  "oracle_verify": ${oracle_verify},
  "prompt": "${prompt}",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

if [ "${oracle_verify}" = "true" ]; then
  echo "[Ralph Loop] Started with Oracle verification (ulw-loop mode)"
else
  echo "[Ralph Loop] Started (standard mode)"
fi
echo "State: ${STATE_FILE}"
