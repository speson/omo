#!/usr/bin/env bash
# Send OS notification when a long-running task completes
# Usage: notify.sh <title> [message]
# Supports macOS (osascript) and Linux (notify-send)
set -eu

title="${1:-omo}"
message="${2:-Task completed}"

if [ "$(uname)" = "Darwin" ]; then
  osascript -e "display notification \"${message}\" with title \"${title}\"" 2>/dev/null || true
elif command -v notify-send >/dev/null 2>&1; then
  notify-send "${title}" "${message}" 2>/dev/null || true
else
  echo "[notify] ${title}: ${message}"
fi
