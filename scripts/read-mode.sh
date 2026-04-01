#!/usr/bin/env bash
# Read the current omo execution mode from .omo/config.json
# Usage: read-mode.sh
# Output: "lean", "standard", or "thorough"
# Defaults to "standard" if config is absent or field is missing
set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH='' cd -- "${script_dir}/.." && pwd)
project_dir="${CLAUDE_PROJECT_DIR:-.}"

# Config lookup: project dir first, then plugin repo root
config_file=""
if [ -f "${project_dir}/.omo/config.json" ]; then
  config_file="${project_dir}/.omo/config.json"
elif [ -f "${repo_root}/.omo/config.json" ]; then
  config_file="${repo_root}/.omo/config.json"
fi

if [ -z "${config_file}" ]; then
  printf 'standard\n'
  exit 0
fi

mode=""

if command -v jq >/dev/null 2>&1; then
  mode=$(jq -r 'if .mode == null then "" else .mode end' "${config_file}" 2>/dev/null || true)
elif command -v python3 >/dev/null 2>&1; then
  mode=$(python3 2>/dev/null - "${config_file}" <<'PYEOF' || true
import json, sys
try:
    with open(sys.argv[1]) as f:
        d = json.load(f)
    v = d.get("mode", "")
    if v:
        print(v)
except Exception:
    pass
PYEOF
)
fi

# Validate against known values; default to standard for anything unrecognised
case "${mode}" in
  lean|standard|thorough)
    printf '%s\n' "${mode}"
    ;;
  *)
    printf 'standard\n'
    ;;
esac
