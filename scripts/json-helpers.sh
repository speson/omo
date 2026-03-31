#!/usr/bin/env bash
# json-helpers.sh — shared JSON field reader and escape functions
# Source this file; do not execute it directly.
# Usage: source "$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)/json-helpers.sh"
#
# Functions:
#   json_str <field> <file>   — read a string field (e.g. json_str goal boulder.json)
#   json_raw <field> <file>   — read a raw value: boolean, number, null, or string
#   json_num <field> <file>   — read a numeric field, defaults to 0
#   json_escape <string>      — escape a string for safe JSON embedding

# json_str <field> <json-file>
# Returns the string value of a JSON field, or empty if not found.
json_str() {
  if command -v jq >/dev/null 2>&1; then
    jq -r ".$1 // empty" "$2" 2>/dev/null || true
  else
    grep -o "\"$1\" *: *\"[^\"]*\"" "$2" 2>/dev/null | cut -d'"' -f4 || true
  fi
}

# json_raw <field> <json-file>
# Returns the raw value of a JSON field (boolean, number, null, or string).
json_raw() {
  if command -v jq >/dev/null 2>&1; then
    jq -r ".$1 // empty" "$2" 2>/dev/null || true
  else
    grep -o "\"$1\" *: *[^,}]*" "$2" 2>/dev/null | sed 's/.*: *//; s/[[:space:]]*$//' || true
  fi
}

# json_num <field> <json-file>
# Returns the numeric value of a JSON field, or 0 if not found/invalid.
json_num() {
  local val
  if command -v jq >/dev/null 2>&1; then
    val=$(jq -r ".$1 // 0" "$2" 2>/dev/null || echo "0")
  else
    val=$(grep -o "\"$1\" *: *[0-9]*" "$2" 2>/dev/null | sed 's/.*: *//' || echo "0")
  fi
  # Ensure numeric output
  case "${val}" in
    *[!0-9]*) echo "0" ;;
    "") echo "0" ;;
    *) echo "${val}" ;;
  esac
}

# json_escape <string>
# Escapes backslash, double quotes, and tabs for safe JSON embedding.
# Newlines are collapsed to spaces.
json_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/	/\\t/g' | tr '\n' ' '; }
