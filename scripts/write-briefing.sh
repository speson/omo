#!/usr/bin/env bash
# Write an agent briefing to .claude/state/briefings/
# Usage: write-briefing.sh <agent-name> <task-slug> [summary]
set -eu

agent="${1:-}"
slug="${2:-}"
summary="${3:-}"

if [ -z "${agent}" ] || [ -z "${slug}" ]; then
  echo "Usage: write-briefing.sh <agent-name> <task-slug> [summary]" >&2
  exit 1
fi

BRIEFINGS_DIR=".claude/state/briefings"
mkdir -p "${BRIEFINGS_DIR}"

timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
# Sanitize agent/slug for safe filename (replace problematic chars including newlines)
safe_fn_agent=$(printf '%s' "${agent}" | tr '/\\:\n' '----')
safe_fn_slug=$(printf '%s' "${slug}" | tr '/\\:\n' '----')
filename="${BRIEFINGS_DIR}/${safe_fn_slug}-${safe_fn_agent}-$(date -u +%Y%m%d-%H%M%S).md"

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
template="${script_dir}/../templates/briefing.md"

if [ -f "${template}" ]; then
  # Sanitize for sed replacement (strip newlines, escape \, /, &)
  sed_safe() { printf '%s' "$1" | tr '\n' ' ' | sed 's/[\\\/&]/\\&/g'; }
  safe_agent=$(sed_safe "${agent}")
  safe_slug=$(sed_safe "${slug}")
  sed -e "s/\[agent-name\]/${safe_agent}/g" \
      -e "s/\[task-description\]/${safe_slug}/g" \
      -e "s/\[ISO timestamp\]/${timestamp}/g" \
      "${template}" > "${filename}"
else
  cat > "${filename}" <<EOF
# Agent Briefing

**Agent**: ${agent}
**Task**: ${slug}
**Date**: ${timestamp}

## Summary

${summary}

## Metadata

- Confidence: MEDIUM
- Escalation: none
- Next agent: none
EOF
fi

echo "${filename}"
