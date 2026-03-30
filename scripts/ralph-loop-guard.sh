#!/usr/bin/env bash
# Ralph Loop Stop Hook — 3-phase state machine
#
# Intercepts agent stop events based on current phase:
#   working              → block stop, inject continuation prompt
#   verification_pending → block stop, inject "call Oracle" prompt
#   verified             → allow stop
#
# Exit codes:
#   0 = allow stop
#   2 = block stop (stdout is fed back to agent)
#
# State file: .claude/state/ralph-loop.json
set -eu

STATE_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/state"
STATE_FILE="${STATE_DIR}/ralph-loop.json"

# JSON field reader: prefers jq, falls back to grep+cut
json_str()  { if command -v jq >/dev/null 2>&1; then jq -r ".$1" "$2"; else grep -o "\"$1\" *: *\"[^\"]*\"" "$2" | cut -d'"' -f4; fi; }
json_raw()  { if command -v jq >/dev/null 2>&1; then jq -r ".$1" "$2"; else grep -o "\"$1\" *: *[a-z0-9]*" "$2" | sed 's/.*: *//'; fi; }

# No state file = no active loop
if [ ! -f "${STATE_FILE}" ]; then
  exit 0
fi

# Read state fields
active=$(json_raw active "${STATE_FILE}")
if [ "${active}" != "true" ]; then
  exit 0
fi

phase=$(json_str phase "${STATE_FILE}")
iteration=$(json_raw iteration "${STATE_FILE}")
max_iterations=$(json_raw max_iterations "${STATE_FILE}")
prompt=$(json_str prompt "${STATE_FILE}")
oracle_verify=$(json_raw oracle_verify "${STATE_FILE}")

# Defaults
: "${phase:=working}"
: "${iteration:=0}"
: "${max_iterations:=100}"
: "${oracle_verify:=false}"

# ─── Phase: verified ──────────────────────────────────────────────
# Task is complete (and Oracle verified if required). Allow stop.
if [ "${phase}" = "verified" ]; then
  iteration_count="${iteration}"
  rm -f "${STATE_FILE}"
  echo "[Ralph Loop] Complete after ${iteration_count} iteration(s)."
  script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
  bash "${script_dir}/notify.sh" "omo" "Ralph Loop complete (${iteration_count} iterations)" 2>/dev/null || true
  exit 0
fi

# ─── Max iterations check ─────────────────────────────────────────
if [ "${iteration}" -ge "${max_iterations}" ]; then
  rm -f "${STATE_FILE}"
  echo "[Ralph Loop] Max iterations (${max_iterations}) reached. Loop force-stopped."
  exit 0
fi

# Increment iteration
new_iteration=$((iteration + 1))
tmp_file="${STATE_FILE}.tmp"
if command -v jq >/dev/null 2>&1; then
  jq --argjson i "${new_iteration}" '.iteration = $i' "${STATE_FILE}" > "${tmp_file}"
else
  sed "s/\"iteration\"[[:space:]]*:[[:space:]]*${iteration}\([^0-9]\)/\"iteration\":${new_iteration}\1/" "${STATE_FILE}" > "${tmp_file}"
fi
mv "${tmp_file}" "${STATE_FILE}"

# ─── Phase: verification_pending ──────────────────────────────────
# Agent said DONE but Oracle hasn't verified yet.
if [ "${phase}" = "verification_pending" ]; then
  cat <<EOF
[RALPH LOOP — ORACLE VERIFICATION REQUIRED — Iteration ${new_iteration}/${max_iterations}]

You marked the task as done, but Oracle has NOT verified it yet.

REQUIRED NOW:
1. Call Oracle using: task(subagent_type="oracle", prompt="...")
2. In the Oracle prompt, include:
   - The original task description
   - A summary of all changes made
   - Ask Oracle to review SKEPTICALLY and CRITICALLY
   - Tell Oracle to look for reasons the task may still be incomplete or wrong
3. Based on Oracle's response:
   - If Oracle approves: run \`bash scripts/ralph-loop-verified.sh\`
   - If Oracle finds issues: run \`bash scripts/ralph-loop-reject.sh\` and fix the issues

DO NOT skip Oracle verification. DO NOT mark as verified without actually calling Oracle.

Original task:
${prompt}
EOF
  exit 2
fi

# ─── Phase: working ───────────────────────────────────────────────
# Task is not yet complete. Block stop and inject continuation.
if [ "${oracle_verify}" = "true" ]; then
  # ULW-loop mode: agent must run ralph-loop-done.sh when it believes task is complete
  cat <<EOF
[RALPH LOOP (ULW) — Iteration ${new_iteration}/${max_iterations}]

The task is NOT complete yet. Continue working.

REQUIRED:
- Review your progress so far (check todo list)
- Continue from where you left off
- When you believe the task is FULLY complete:
  1. Run: \`bash scripts/ralph-loop-done.sh\`
  2. This will trigger Oracle verification
  3. Oracle must approve before the loop ends
- Do NOT claim completion without running the done script

Original task:
${prompt}
EOF
else
  # Standard ralph-loop mode: agent must run ralph-loop-done.sh when complete
  cat <<EOF
[RALPH LOOP — Iteration ${new_iteration}/${max_iterations}]

The task is NOT complete yet. Continue working.

REQUIRED:
- Review your progress so far (check todo list)
- Continue from where you left off
- When FULLY complete and verified, run: \`bash scripts/ralph-loop-done.sh\`
- Do NOT run the done script until the task is truly finished

Original task:
${prompt}
EOF
fi

exit 2
