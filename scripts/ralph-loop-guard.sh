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

STATE_DIR=".claude/state"
STATE_FILE="${STATE_DIR}/ralph-loop.json"

# No state file = no active loop
if [ ! -f "${STATE_FILE}" ]; then
  exit 0
fi

# Read state fields
active=$(cat "${STATE_FILE}" | grep -o '"active":[a-z]*' | cut -d: -f2)
if [ "${active}" != "true" ]; then
  exit 0
fi

phase=$(cat "${STATE_FILE}" | grep -o '"phase":"[^"]*"' | cut -d'"' -f4)
iteration=$(cat "${STATE_FILE}" | grep -o '"iteration":[0-9]*' | cut -d: -f2)
max_iterations=$(cat "${STATE_FILE}" | grep -o '"max_iterations":[0-9]*' | cut -d: -f2)
prompt=$(cat "${STATE_FILE}" | grep -o '"prompt":"[^"]*"' | cut -d'"' -f4)
oracle_verify=$(cat "${STATE_FILE}" | grep -o '"oracle_verify":[a-z]*' | cut -d: -f2)

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
sed "s/\"iteration\":${iteration}/\"iteration\":${new_iteration}/" "${STATE_FILE}" > "${tmp_file}"
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
