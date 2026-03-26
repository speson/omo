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
filename="${BRIEFINGS_DIR}/${slug}-${agent}-$(date -u +%Y%m%d-%H%M%S).md"

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
template="${script_dir}/../templates/briefing.md"

if [ -f "${template}" ]; then
  sed -e "s/\[agent-name\]/${agent}/g" \
      -e "s/\[task-description\]/${slug}/g" \
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
