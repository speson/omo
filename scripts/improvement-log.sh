#!/usr/bin/env bash
# Log an improvement pipeline run
# Usage: improvement-log.sh <slug> [summary]
set -eu

slug="${1:-}"
summary="${2:-}"

if [ -z "${slug}" ]; then
  echo "Usage: improvement-log.sh <slug> [summary]" >&2
  exit 1
fi

project_dir="${CLAUDE_PROJECT_DIR:-.}"
improvements_dir="${project_dir}/.claude/state/improvements"

mkdir -p "${improvements_dir}"

timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo "${timestamp} ${slug} ${summary}" >> "${improvements_dir}/history.log"

echo "Logged: ${slug}"
