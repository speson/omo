#!/usr/bin/env bash
# Send OS notification when a long-running task completes
# Usage: notify.sh <title> [message]
# Supports macOS (osascript) and Linux (notify-send)
# Exit codes:
#   0 = Notification sent (or fallback to stderr)
set -eu

title="${1:-omo}"
message="${2:-Task completed}"

if [ "$(uname)" = "Darwin" ]; then
  # Sanitize inputs to prevent AppleScript injection
  safe_title=$(printf '%.100s' "${title}" | tr -d '"\\')
  safe_message=$(printf '%.200s' "${message}" | tr -d '"\\')
  osascript -e "display notification \"${safe_message}\" with title \"${safe_title}\"" 2>/dev/null || {
    echo "[notify] macOS notification failed; is osascript available?" >&2
  }
elif command -v notify-send >/dev/null 2>&1; then
  notify-send "${title}" "${message}" 2>/dev/null || {
    echo "[notify] notify-send failed; check D-Bus" >&2
  }
else
  echo "[notify] ${title}: ${message}" >&2
fi
