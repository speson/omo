#!/usr/bin/env bash
# Record a Boulder attempt outcome
# Usage: boulder-attempt.sh <outcome> [reason]
# Exit codes:
#   0 = Attempt recorded successfully
#   1 = Invalid arguments, disabled, or no active boulder
set -eu

project_dir="${CLAUDE_PROJECT_DIR:-.}"
boulder_file="${project_dir}/.claude/state/boulder.json"
script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
source "${script_dir}/json-helpers.sh"

if [ $# -lt 1 ]; then
  echo "Usage: boulder-attempt.sh <outcome> [reason]" >&2
  exit 1
fi

outcome="$1"
reason="${2:-}"

case "${outcome}" in
  working|interrupted|failed|completed) ;;
  *) echo "Invalid outcome: ${outcome}. Must be: working, interrupted, failed, completed" >&2; exit 1 ;;
esac

enabled=$(bash "${script_dir}/read-config.sh" boulder.enabled true 2>/dev/null || echo "true")
if [ "${enabled}" != "true" ]; then
  echo "[Boulder] Disabled via config."
  exit 0
fi

if [ ! -f "${boulder_file}" ]; then
  echo "No active boulder. Run boulder-init.sh first." >&2
  exit 1
fi

now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if command -v jq >/dev/null 2>&1; then
  tmp_file="${boulder_file}.tmp"

  # Increment attempts
  jq --arg outcome "${outcome}" \
     --arg reason "${reason}" \
     --arg now "${now}" '
    .attempts += 1 |
    .last_outcome = $outcome |
    .updated_at = $now |
    if $outcome == "failed" then
      .consecutive_failures += 1 |
      .last_failure_reason = $reason
    elif $outcome == "working" or $outcome == "completed" then
      .consecutive_failures = 0 |
      .last_failure_reason = null
    else
      .
    end
  ' "${boulder_file}" > "${tmp_file}"
  mv "${tmp_file}" "${boulder_file}"
else
  # Fallback: read current values with json_num
  attempts=$(json_num attempts "${boulder_file}")
  consec=$(json_num consecutive_failures "${boulder_file}")
  new_attempts=$((attempts + 1))

  if [ "${outcome}" = "failed" ]; then
    new_consec=$((consec + 1))
  elif [ "${outcome}" = "working" ] || [ "${outcome}" = "completed" ]; then
    new_consec=0
  else
    new_consec="${consec}"
  fi

  if [ "$(uname)" = "Darwin" ]; then
    sed -i '' \
      -e "s/\"attempts\" *: *[0-9]*\([^0-9]\)/\"attempts\": ${new_attempts}\1/" \
      -e "s/\"consecutive_failures\" *: *[0-9]*\([^0-9]\)/\"consecutive_failures\": ${new_consec}\1/" \
      -e "s/\"last_outcome\" *: *\"[^\"]*\"/\"last_outcome\": \"${outcome}\"/" \
      -e "s/\"updated_at\" *: *\"[^\"]*\"/\"updated_at\": \"${now}\"/" \
      "${boulder_file}"
  else
    sed -i \
      -e "s/\"attempts\" *: *[0-9]*\([^0-9]\)/\"attempts\": ${new_attempts}\1/" \
      -e "s/\"consecutive_failures\" *: *[0-9]*\([^0-9]\)/\"consecutive_failures\": ${new_consec}\1/" \
      -e "s/\"last_outcome\" *: *\"[^\"]*\"/\"last_outcome\": \"${outcome}\"/" \
      -e "s/\"updated_at\" *: *\"[^\"]*\"/\"updated_at\": \"${now}\"/" \
      "${boulder_file}"
  fi
fi

# Read current state
if command -v jq >/dev/null 2>&1; then
  consec_now=$(jq -r '.consecutive_failures' "${boulder_file}")
  attempts_now=$(jq -r '.attempts' "${boulder_file}")
  max_now=$(jq -r '.max_attempts' "${boulder_file}")
else
  consec_now=$(json_num consecutive_failures "${boulder_file}")
  attempts_now=$(json_num attempts "${boulder_file}")
  max_now=$(json_num max_attempts "${boulder_file}")
fi

echo "[Boulder] Attempt ${attempts_now}/${max_now}: ${outcome}"

if [ "${consec_now}" -ge 2 ] 2>/dev/null; then
  echo "[Boulder] WARNING: ${consec_now} consecutive failures. Consider escalating to oracle."
fi
