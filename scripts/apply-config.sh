#!/usr/bin/env bash
# Apply category model assignments from .omo/config.json to agent frontmatter
# Usage: apply-config.sh [--dry-run]
set -eu

dry_run=0
for arg in "$@"; do
  if [ "${arg}" = "--dry-run" ]; then
    dry_run=1
  fi
done

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH='' cd -- "${script_dir}/.." && pwd)
config_file="${repo_root}/.omo/config.json"
agents_dir="${repo_root}/agents"

if [ ! -f "${config_file}" ]; then
  echo "No config file found. Run: bash scripts/init-config.sh"
  exit 1
fi

# ─── JSON lookup helper ───────────────────────────────────────────────────────
if command -v jq >/dev/null 2>&1; then
  USE_JQ=1
elif command -v python3 >/dev/null 2>&1; then
  USE_JQ=0
else
  echo "Error: jq or python3 required to read config" >&2
  exit 1
fi

valid_categories="fast-search verification implementation planning deep-reasoning research media"

config_model_for_category() {
  local cat="${1}"
  # Validate category against whitelist before interpolation
  local valid=0
  for vc in ${valid_categories}; do
    [ "${cat}" = "${vc}" ] && valid=1 && break
  done
  if [ "${valid}" -eq 0 ]; then
    echo ""
    return
  fi
  if [ "${USE_JQ}" -eq 1 ]; then
    jq -r ".categories[\"${cat}\"].model // empty" "${config_file}" 2>/dev/null || true
  else
    python3 2>/dev/null - "${config_file}" "${cat}" <<'PYEOF' || true
import json, sys
try:
    with open(sys.argv[1]) as f:
        d = json.load(f)
    v = d.get('categories', {}).get(sys.argv[2], {}).get('model', '')
    print(v if v else '')
except Exception:
    pass
PYEOF
  fi
}

# ─── Detect sed in-place flag ─────────────────────────────────────────────────
platform=$(uname -s)
if [ "${platform}" = "Darwin" ]; then
  SED_INPLACE=( sed -i '' )
else
  SED_INPLACE=( sed -i )
fi

# ─── Process agents ──────────────────────────────────────────────────────────
changes=0
total=0

for agent_file in "${agents_dir}"/*.md; do
  [ -f "${agent_file}" ] || continue
  agent_name=$(basename "${agent_file}" .md)
  total=$((total + 1))

  # Read category from frontmatter
  category=$(grep '^category:' "${agent_file}" 2>/dev/null | head -1 | sed 's/^category:[[:space:]]*//' || true)
  if [ -z "${category}" ]; then
    echo "  ${agent_name}: SKIP (no category field)"
    continue
  fi

  # Look up model for this category
  new_model=$(config_model_for_category "${category}")
  if [ -z "${new_model}" ]; then
    echo "  ${agent_name}: SKIP (category '${category}' not in config)"
    continue
  fi

  # Read current model from frontmatter
  current_model=$(grep '^model:' "${agent_file}" 2>/dev/null | head -1 | sed 's/^model:[[:space:]]*//' || true)

  # Validate model value before sed interpolation
  case "${new_model}" in
    haiku|sonnet|opus) ;;
    *)
      echo "  ${agent_name}: SKIP (invalid model '${new_model}')"
      continue
      ;;
  esac

  if [ "${current_model}" = "${new_model}" ]; then
    echo "  ${agent_name}: ${current_model} (unchanged)"
  else
    changes=$((changes + 1))
    if [ "${dry_run}" -eq 1 ]; then
      echo "  ${agent_name}: ${current_model} → ${new_model} (would change)"
    else
      "${SED_INPLACE[@]}" "s/^model: .*/model: ${new_model}/" "${agent_file}"
      echo "  ${agent_name}: ${current_model} → ${new_model}"
    fi
  fi
done

# ─── Summary ─────────────────────────────────────────────────────────────────
if [ "${dry_run}" -eq 1 ]; then
  echo "Dry run: ${changes} changes would be made to ${total} agents"
else
  echo "Applied: ${changes} changes to ${total} agents"
fi
