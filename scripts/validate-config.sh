#!/usr/bin/env bash
# Validate .omo/config.json structure and field values
# Usage: validate-config.sh
set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH='' cd -- "${script_dir}/.." && pwd)
config_file="${repo_root}/.omo/config.json"

errors=0
warnings=0

# ─── Existence check ─────────────────────────────────────────────────────────
if [ ! -f "${config_file}" ]; then
  echo "No config file (.omo/config.json)"
  exit 0
fi

# ─── JSON parsing helpers ─────────────────────────────────────────────────────
if command -v jq >/dev/null 2>&1; then
  USE_JQ=1
elif command -v python3 >/dev/null 2>&1; then
  USE_JQ=0
else
  echo "Config: FAIL (no jq or python3 available to parse JSON)"
  exit 1
fi

json_get() {
  # json_get <path> — returns value or empty string
  if [ "${USE_JQ}" -eq 1 ]; then
    jq -r "${1} // empty" "${config_file}" 2>/dev/null || true
  else
    python3 2>/dev/null - "${config_file}" "${1}" <<'PYEOF' || true
import json, sys
try:
    with open(sys.argv[1]) as f:
        d = json.load(f)
    # sys.argv[2] is a jq-style path like .categories.sonnet.model
    path = sys.argv[2].lstrip('.')
    keys = path.split('.') if path else []
    v = d
    for k in keys:
        v = v[k]
    if v is None:
        print('')
    elif isinstance(v, bool):
        print(str(v).lower())
    else:
        print(v)
except (KeyError, TypeError, IndexError):
    pass
except Exception:
    pass
PYEOF
  fi
}

json_keys() {
  # json_keys <path> — returns newline-separated keys of an object
  if [ "${USE_JQ}" -eq 1 ]; then
    jq -r "${1} | keys[]" "${config_file}" 2>/dev/null || true
  else
    python3 2>/dev/null - "${config_file}" "${1}" <<'PYEOF' || true
import json, sys
try:
    with open(sys.argv[1]) as f:
        d = json.load(f)
    path = sys.argv[2].lstrip('.')
    keys = path.split('.') if path else []
    v = d
    for k in keys:
        v = v[k]
    for k in v.keys():
        print(k)
except Exception:
    pass
PYEOF
  fi
}

json_valid() {
  if [ "${USE_JQ}" -eq 1 ]; then
    jq empty "${config_file}" >/dev/null 2>&1
  else
    python3 -c "import json,sys; json.load(open(sys.argv[1]))" "${config_file}" >/dev/null 2>&1
  fi
}

# ─── Valid JSON ───────────────────────────────────────────────────────────────
if ! json_valid; then
  echo "  ERROR: invalid JSON"
  errors=$((errors + 1))
  echo "Config: FAIL (${errors} errors)"
  exit 1
fi

# ─── version field ────────────────────────────────────────────────────────────
version=$(json_get '.version')
if [ -z "${version}" ]; then
  echo "  ERROR: missing 'version' field"
  errors=$((errors + 1))
elif [ "${version}" != "1" ]; then
  echo "  ERROR: version must be \"1\", got \"${version}\""
  errors=$((errors + 1))
fi

# ─── categories object ───────────────────────────────────────────────────────
valid_categories="fast-search verification implementation planning deep-reasoning research media"
categories_exist=$(json_get '.categories | type' 2>/dev/null || true)
if [ -z "${categories_exist}" ] || [ "${categories_exist}" = "null" ]; then
  echo "  ERROR: missing 'categories' object"
  errors=$((errors + 1))
else
  while IFS= read -r cat_key; do
    [ -z "${cat_key}" ] && continue
    found=0
    for vc in ${valid_categories}; do
      if [ "${cat_key}" = "${vc}" ]; then
        found=1
        break
      fi
    done
    if [ "${found}" -eq 0 ]; then
      echo "  ERROR: unknown category '${cat_key}' (must be one of: ${valid_categories})"
      errors=$((errors + 1))
    fi
    cat_model=$(json_get ".categories[\"${cat_key}\"].model")
    case "${cat_model}" in
      haiku|sonnet|opus) ;;
      "")
        echo "  ERROR: categories.${cat_key} missing 'model'"
        errors=$((errors + 1))
        ;;
      *)
        echo "  ERROR: categories.${cat_key}.model must be haiku|sonnet|opus, got '${cat_model}'"
        errors=$((errors + 1))
        ;;
    esac
  done <<EOF
$(json_keys '.categories')
EOF
fi

# ─── ralph-loop.max_iterations ───────────────────────────────────────────────
max_iter=$(json_get '.["ralph-loop"].max_iterations')
if [ -n "${max_iter}" ] && [ "${max_iter}" != "null" ]; then
  case "${max_iter}" in
    ''|*[!0-9]*)
      echo "  ERROR: ralph-loop.max_iterations must be a positive integer, got '${max_iter}'"
      errors=$((errors + 1))
      ;;
    *)
      if [ "${max_iter}" -le 0 ]; then
        echo "  ERROR: ralph-loop.max_iterations must be positive, got ${max_iter}"
        errors=$((errors + 1))
      fi
      ;;
  esac
fi

# ─── ralph-loop.oracle_default ───────────────────────────────────────────────
oracle_default=$(json_get '.["ralph-loop"].oracle_default')
if [ -n "${oracle_default}" ] && [ "${oracle_default}" != "null" ]; then
  case "${oracle_default}" in
    true|false) ;;
    *)
      echo "  ERROR: ralph-loop.oracle_default must be boolean, got '${oracle_default}'"
      errors=$((errors + 1))
      ;;
  esac
fi

# ─── spawn.max_concurrent_agents ─────────────────────────────────────────────
max_agents=$(json_get '.spawn.max_concurrent_agents')
if [ -n "${max_agents}" ] && [ "${max_agents}" != "null" ]; then
  case "${max_agents}" in
    ''|*[!0-9]*)
      echo "  ERROR: spawn.max_concurrent_agents must be a positive integer (1-20), got '${max_agents}'"
      errors=$((errors + 1))
      ;;
    *)
      if [ "${max_agents}" -lt 1 ] || [ "${max_agents}" -gt 20 ]; then
        echo "  ERROR: spawn.max_concurrent_agents must be 1-20, got ${max_agents}"
        errors=$((errors + 1))
      fi
      ;;
  esac
fi

# ─── boulder.enabled ──────────────────────────────────────────────────────────
boulder_enabled=$(json_get '.boulder.enabled')
if [ -n "${boulder_enabled}" ] && [ "${boulder_enabled}" != "null" ]; then
  case "${boulder_enabled}" in
    true|false) ;;
    *)
      echo "  ERROR: boulder.enabled must be boolean, got '${boulder_enabled}'"
      errors=$((errors + 1))
      ;;
  esac
fi

# ─── boulder.max_attempts ────────────────────────────────────────────────────
boulder_max=$(json_get '.boulder.max_attempts')
if [ -n "${boulder_max}" ] && [ "${boulder_max}" != "null" ]; then
  case "${boulder_max}" in
    ''|*[!0-9]*)
      echo "  ERROR: boulder.max_attempts must be a positive integer, got '${boulder_max}'"
      errors=$((errors + 1))
      ;;
    *)
      if [ "${boulder_max}" -le 0 ]; then
        echo "  ERROR: boulder.max_attempts must be positive, got ${boulder_max}"
        errors=$((errors + 1))
      fi
      ;;
  esac
fi

# ─── boulder.auto_resume ────────────────────────────────────────────────────
boulder_auto=$(json_get '.boulder.auto_resume')
if [ -n "${boulder_auto}" ] && [ "${boulder_auto}" != "null" ]; then
  case "${boulder_auto}" in
    true|false) ;;
    *)
      echo "  ERROR: boulder.auto_resume must be boolean, got '${boulder_auto}'"
      errors=$((errors + 1))
      ;;
  esac
fi

# ─── teams.enabled ────────────────────────────────────────────────────────────
teams_enabled=$(json_get '.teams.enabled')
if [ -n "${teams_enabled}" ] && [ "${teams_enabled}" != "null" ]; then
  case "${teams_enabled}" in
    true|false) ;;
    *)
      echo "  ERROR: teams.enabled must be boolean, got '${teams_enabled}'"
      errors=$((errors + 1))
      ;;
  esac
fi

# ─── teams.max_teammates ─────────────────────────────────────────────────────
teams_max=$(json_get '.teams.max_teammates')
if [ -n "${teams_max}" ] && [ "${teams_max}" != "null" ]; then
  case "${teams_max}" in
    ''|*[!0-9]*)
      echo "  ERROR: teams.max_teammates must be a positive integer (1-20), got '${teams_max}'"
      errors=$((errors + 1))
      ;;
    *)
      if [ "${teams_max}" -lt 1 ] || [ "${teams_max}" -gt 20 ]; then
        echo "  ERROR: teams.max_teammates must be 1-20, got ${teams_max}"
        errors=$((errors + 1))
      fi
      ;;
  esac
fi

# ─── teams.auto_escalation ───────────────────────────────────────────────────
teams_esc=$(json_get '.teams.auto_escalation')
if [ -n "${teams_esc}" ] && [ "${teams_esc}" != "null" ]; then
  case "${teams_esc}" in
    true|false) ;;
    *)
      echo "  ERROR: teams.auto_escalation must be boolean, got '${teams_esc}'"
      errors=$((errors + 1))
      ;;
  esac
fi

# ─── teams.notify_on_completion ──────────────────────────────────────────────
teams_notify=$(json_get '.teams.notify_on_completion')
if [ -n "${teams_notify}" ] && [ "${teams_notify}" != "null" ]; then
  case "${teams_notify}" in
    true|false) ;;
    *)
      echo "  ERROR: teams.notify_on_completion must be boolean, got '${teams_notify}'"
      errors=$((errors + 1))
      ;;
  esac
fi

# ─── evolve.max_discovery_agents ─────────────────────────────────────────
evolve_max=$(json_get '.evolve.max_discovery_agents')
if [ -n "${evolve_max}" ] && [ "${evolve_max}" != "null" ]; then
  case "${evolve_max}" in
    ''|*[!0-9]*)
      echo "  ERROR: evolve.max_discovery_agents must be a positive integer (1-6), got '${evolve_max}'"
      errors=$((errors + 1))
      ;;
    *)
      if [ "${evolve_max}" -lt 1 ] || [ "${evolve_max}" -gt 6 ]; then
        echo "  ERROR: evolve.max_discovery_agents must be 1-6, got ${evolve_max}"
        errors=$((errors + 1))
      fi
      ;;
  esac
fi

# ─── evolve.auto_plan ───────────────────────────────────────────────────
evolve_plan=$(json_get '.evolve.auto_plan')
if [ -n "${evolve_plan}" ] && [ "${evolve_plan}" != "null" ]; then
  case "${evolve_plan}" in
    true|false) ;;
    *)
      echo "  ERROR: evolve.auto_plan must be boolean, got '${evolve_plan}'"
      errors=$((errors + 1))
      ;;
  esac
fi

# ─── evolve.include_memory ──────────────────────────────────────────────
evolve_mem=$(json_get '.evolve.include_memory')
if [ -n "${evolve_mem}" ] && [ "${evolve_mem}" != "null" ]; then
  case "${evolve_mem}" in
    true|false) ;;
    *)
      echo "  ERROR: evolve.include_memory must be boolean, got '${evolve_mem}'"
      errors=$((errors + 1))
      ;;
  esac
fi

# ─── disabled_skills ─────────────────────────────────────────────────────────
ds_type=$(json_get '.disabled_skills | type' 2>/dev/null || true)
if [ -n "${ds_type}" ] && [ "${ds_type}" != "null" ] && [ "${ds_type}" != "array" ]; then
  echo "  ERROR: disabled_skills must be an array, got type '${ds_type}'"
  errors=$((errors + 1))
fi

# ─── Model hierarchy warning ─────────────────────────────────────────────────
model_rank() {
  case "${1}" in
    haiku)  echo 1 ;;
    sonnet) echo 2 ;;
    opus)   echo 3 ;;
    *)      echo 0 ;;
  esac
}

planning_model=$(json_get '.categories.planning.model' 2>/dev/null || true)
deep_model=$(json_get '.categories["deep-reasoning"].model' 2>/dev/null || true)

if [ -n "${planning_model}" ] && [ -n "${deep_model}" ]; then
  planning_rank=$(model_rank "${planning_model}")
  deep_rank=$(model_rank "${deep_model}")
  if [ "${deep_rank}" -lt "${planning_rank}" ]; then
    echo "  WARNING: deep-reasoning uses '${deep_model}' which is lower than planning '${planning_model}'"
    warnings=$((warnings + 1))
  fi
fi

# ─── Summary ─────────────────────────────────────────────────────────────────
if [ "${errors}" -gt 0 ]; then
  echo "Config: FAIL (${errors} errors)"
  exit 1
else
  if [ "${warnings}" -gt 0 ]; then
    echo "Config: PASS (${warnings} warning(s))"
  else
    echo "Config: PASS"
  fi
  exit 0
fi
