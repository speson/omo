#!/usr/bin/env bash
# Log a task lifecycle event to task-history.log
# Usage: log-task-event.sh <event> <task-slug> [details]
# Events: created, started, completed, cancelled, handoff
set -eu

event="${1:-}"
slug="${2:-}"
details="${3:-}"

if [ -z "${event}" ] || [ -z "${slug}" ]; then
  echo "Usage: log-task-event.sh <event> <task-slug> [details]" >&2
  exit 1
fi

STATE_DIR=".claude/state"
LOG_FILE="${STATE_DIR}/task-history.log"

mkdir -p "${STATE_DIR}"

timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "${timestamp} | ${event} | ${slug} | ${details}" >> "${LOG_FILE}"
echo "[task-history] Logged: ${event} ${slug}"
