#!/usr/bin/env bash
# Check agent briefings for escalation signals
# Usage: escalation-check.sh [briefing-file]
# Parses Confidence and Escalation metadata from agent briefings
set -eu

BRIEFINGS_DIR="${CLAUDE_PROJECT_DIR:-.}/.claude/state/briefings"

if [ -n "${1:-}" ] && [ -f "$1" ]; then
  files="$1"
elif [ -d "${BRIEFINGS_DIR}" ]; then
  files=$(ls -t "${BRIEFINGS_DIR}"/*.md 2>/dev/null | head -5)
else
  echo "No briefings found."
  exit 0
fi

escalations=0

for f in ${files}; do
  fname=$(basename "${f}")
  confidence=$(grep -i '^- Confidence:' "${f}" 2>/dev/null | head -1 | sed 's/.*: *//' || echo "UNKNOWN")
  escalation=$(grep -i '^- Escalation:' "${f}" 2>/dev/null | head -1 | sed 's/.*: *//' || echo "none")

  if [ "${escalation}" = "recommended" ] || [ "${confidence}" = "LOW" ]; then
    echo "ESCALATE: ${fname} (confidence=${confidence}, escalation=${escalation})"
    escalations=$((escalations + 1))
  else
    echo "OK: ${fname} (confidence=${confidence})"
  fi
done

if [ "${escalations}" -gt 0 ]; then
  echo ""
  echo "${escalations} briefing(s) recommend escalation to a higher-tier agent."
  exit 2
else
  echo ""
  echo "No escalation needed."
  exit 0
fi
