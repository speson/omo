#!/usr/bin/env bash
# json-helpers.sh — shared JSON field reader functions
# Source this file; do not execute it directly.
# Usage: source "$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)/json-helpers.sh"

json_str() { if command -v jq >/dev/null 2>&1; then jq -r ".$1" "$2"; else grep -o "\"$1\" *: *\"[^\"]*\"" "$2" | cut -d'"' -f4; fi; }
json_raw() { if command -v jq >/dev/null 2>&1; then jq -r ".$1" "$2"; else grep -o "\"$1\" *: *[a-z0-9]*" "$2" | sed 's/.*: *//'; fi; }
json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g' | tr '\n' ' '; }
