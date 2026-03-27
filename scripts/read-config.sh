#!/usr/bin/env bash
# Read a value from .omo/config.json using dot-notation path
# Usage: read-config.sh <json-path> [default-value]
# Example: read-config.sh ralph-loop.max_iterations 100
set -eu

json_path="${1:-}"
default_value="${2:-}"

if [ -z "${json_path}" ]; then
  echo "Usage: read-config.sh <json-path> [default-value]" >&2
  exit 1
fi

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH='' cd -- "${script_dir}/.." && pwd)
config_file="${repo_root}/.omo/config.json"

if [ ! -f "${config_file}" ]; then
  printf '%s\n' "${default_value}"
  exit 0
fi

result=""

# Convert dot-path to safe jq expression: a.b-c.d → .a["b-c"].d
# Segments containing non-word characters use bracket notation.
dot_to_jq() {
  local path="${1}"
  local jq_expr=""
  local IFS_bak="${IFS}"
  IFS='.'
  # shellcheck disable=SC2086
  set -- ${path}
  IFS="${IFS_bak}"
  for seg in "$@"; do
    case "${seg}" in
      *[!a-zA-Z0-9_]*)
        jq_expr="${jq_expr}[\"${seg}\"]"
        ;;
      *)
        jq_expr="${jq_expr}.${seg}"
        ;;
    esac
  done
  printf '%s' "${jq_expr}"
}

if command -v jq >/dev/null 2>&1; then
  jq_path=$(dot_to_jq "${json_path}")
  result=$(jq -r "${jq_path} // empty" "${config_file}" 2>/dev/null || true)
elif command -v python3 >/dev/null 2>&1; then
  result=$(python3 2>/dev/null - "${config_file}" "${json_path}" <<'PYEOF' || true
import json, sys
try:
    with open(sys.argv[1]) as f:
        d = json.load(f)
    keys = sys.argv[2].split('.')
    v = d
    for k in keys:
        v = v[k]
    if v is None:
        print('')
    elif isinstance(v, bool):
        print(str(v).lower())
    else:
        print(v)
except (KeyError, TypeError):
    pass
except Exception:
    pass
PYEOF
)
else
  printf '%s\n' "${default_value}"
  exit 0
fi

if [ -z "${result}" ]; then
  printf '%s\n' "${default_value}"
else
  printf '%s\n' "${result}"
fi
