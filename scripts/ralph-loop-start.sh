#!/usr/bin/env bash
# Initialize ralph-loop state file
# Usage: ./scripts/ralph-loop-start.sh "task description" [--oracle] [--max-iterations=N]
#
# Options:
#   --oracle    Enable Oracle verification (ulw-loop mode)
set -eu

STATE_DIR=".claude/state"
STATE_FILE="${STATE_DIR}/ralph-loop.json"

# Read defaults from config if available
script_dir_cfg=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root_cfg=$(CDPATH='' cd -- "${script_dir_cfg}/.." && pwd)
read_cfg() {
  if [ -x "${repo_root_cfg}/scripts/read-config.sh" ]; then
    bash "${repo_root_cfg}/scripts/read-config.sh" "$1" "$2"
  else
    printf '%s' "$2"
  fi
}

# Parse arguments
prompt=""
max_iterations=$(read_cfg "ralph-loop.max_iterations" "100")
oracle_default=$(read_cfg "ralph-loop.oracle_default" "false")
oracle_verify="${oracle_default}"

for arg in "$@"; do
  case "${arg}" in
    --oracle) oracle_verify="true" ;;
    --max-iterations=*) max_iterations="${arg#*=}" ;;
    --*) echo "Unknown flag: ${arg}" >&2; exit 1 ;;
    *) [ -z "${prompt}" ] && prompt="${arg}" ;;
  esac
done

if [ -z "${prompt}" ]; then
  echo "Usage: ralph-loop-start.sh \"task\" [--oracle] [--max-iterations=N]" >&2
  exit 1
fi

mkdir -p "${STATE_DIR}"

# Source shared JSON helpers (includes json_escape for fallback path)
source "$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)/json-helpers.sh"

if command -v jq >/dev/null 2>&1; then
  jq -n \
    --arg prompt "${prompt}" \
    --argjson max "${max_iterations}" \
    --argjson oracle "${oracle_verify}" \
    --arg started "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{active:true,phase:"working",iteration:0,max_iterations:$max,oracle_verify:$oracle,prompt:$prompt,started_at:$started}' \
    > "${STATE_FILE}"
else
  safe_prompt=$(json_escape "${prompt}")
  cat > "${STATE_FILE}" <<EOF
{
  "active": true,
  "phase": "working",
  "iteration": 0,
  "max_iterations": ${max_iterations},
  "oracle_verify": ${oracle_verify},
  "prompt": "${safe_prompt}",
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
fi

if [ "${oracle_verify}" = "true" ]; then
  echo "[Ralph Loop] Started with Oracle verification (ulw-loop mode)"
else
  echo "[Ralph Loop] Started (standard mode)"
fi
echo "State: ${STATE_FILE}"
