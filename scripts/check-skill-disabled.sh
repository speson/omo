#!/usr/bin/env bash
# Check if a skill is disabled via .omo/config.json disabled_skills array
# Usage: check-skill-disabled.sh <skill-name>
# Exit 0 = skill is ALLOWED (not disabled)
# Exit 1 = skill is DISABLED
set -eu

skill_name="${1:-}"
if [ -z "${skill_name}" ]; then
  echo "Usage: check-skill-disabled.sh <skill-name>" >&2
  exit 1
fi

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
project_dir="${CLAUDE_PROJECT_DIR:-.}"
repo_root=$(CDPATH='' cd -- "${script_dir}/.." && pwd)

# Find config file
config_file=""
if [ -f "${project_dir}/.omo/config.json" ]; then
  config_file="${project_dir}/.omo/config.json"
elif [ -f "${repo_root}/.omo/config.json" ]; then
  config_file="${repo_root}/.omo/config.json"
fi

# No config = not disabled
if [ -z "${config_file}" ]; then
  exit 0
fi

# Check if skill is in disabled_skills array
if command -v jq >/dev/null 2>&1; then
  disabled=$(jq -r --arg name "${skill_name}" \
    'if .disabled_skills then (.disabled_skills[] | select(. == $name)) else empty end' \
    "${config_file}" 2>/dev/null || true)
elif command -v python3 >/dev/null 2>&1; then
  disabled=$(python3 2>/dev/null - "${config_file}" "${skill_name}" <<'PYEOF' || true
import json, sys
try:
    with open(sys.argv[1]) as f:
        d = json.load(f)
    if sys.argv[2] in d.get("disabled_skills", []):
        print(sys.argv[2])
except Exception:
    pass
PYEOF
)
else
  # No parser available — assume not disabled
  exit 0
fi

if [ -n "${disabled}" ]; then
  echo "[omo] Skill '${skill_name}' is disabled via config." >&2
  exit 1
fi

exit 0
